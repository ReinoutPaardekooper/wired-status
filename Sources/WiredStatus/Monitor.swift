import AppKit
import SystemConfiguration

final class Monitor {
    private var store: SCDynamicStore?
    private var timer: DispatchSourceTimer?
    private var fallbackTimer: DispatchSourceTimer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var previous: (name: String, sample: CounterSample, time: TimeInterval)?
    private(set) var interfaces: [InterfaceSnapshot] = []
    private(set) var counters: CounterSample?
    private(set) var rate: TrafficRate = .zero
    private(set) var history: [TrafficRate] = []
    private(set) var hasSample = false
    private(set) var primary4: String?
    private(set) var primary6: String?
    private(set) var notificationsWorking = false
    var isVisible = false
    var onChange: (() -> Void)?
    var preferredName: String? = UserDefaults.standard.string(forKey: "selectedInterface")
    private lazy var reader = NetworkReader(store: store)

    var selected: InterfaceSnapshot? {
        if let preferredName, let found = interfaces.first(where: { $0.name == preferredName }) { return found }
        return interfaces.first
    }

    init() {
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                            retain: nil, release: nil, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "WiredStatus.Events" as CFString, { _, _, info in
            guard let info else { return }
            Unmanaged<Monitor>.fromOpaque(info).takeUnretainedValue().refresh()
        }, &context)
        if let store {
            let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6", "State:/Network/Interface"]
            let patterns = ["State:/Network/Interface/.*/(Link|IPv4|IPv6)",
                            "Setup:/Network/Service/.*/Interface"]
            notificationsWorking = SCDynamicStoreSetNotificationKeys(store, keys as CFArray, patterns as CFArray)
                && SCDynamicStoreSetDispatchQueue(store, .main)
        }
        // A slow fallback only if subscribing fails; normal idle operation has no app timer.
        if !notificationsWorking {
            let fallback = DispatchSource.makeTimerSource(queue: .main)
            fallback.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(10))
            fallback.setEventHandler { [weak self] in self?.refresh() }
            fallback.resume()
            fallbackTimer = fallback
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopTimer()
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
            if self?.isVisible == true { self?.startTimer() }
        })
        refresh()
    }

    deinit {
        timer?.cancel()
        fallbackTimer?.cancel()
        if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func refresh() {
        let old = selected
        interfaces = reader.interfaces()
        primary4 = reader.primary4
        primary6 = reader.primary6
        if old?.name != selected?.name || old?.link != selected?.link { resetSamples() }
        // Configuration notifications update metadata, not the timed graph.
        // Only seed a baseline here; subsequent rate samples come from the timer.
        if isVisible && previous == nil { sample() } else { onChange?() }
    }

    func choose(_ name: String?) {
        preferredName = name
        UserDefaults.standard.set(name, forKey: "selectedInterface")
        resetSamples()
        refresh()
    }

    func show() {
        isVisible = true
        resetSamples()
        refresh()
        startTimer()
    }

    func hide() {
        isVisible = false
        stopTimer()
        resetSamples()
    }

    private func startTimer() {
        stopTimer()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(150))
        source.setEventHandler { [weak self] in self?.sample() }
        source.resume()
        timer = source
    }

    private func stopTimer() { timer?.cancel(); timer = nil; previous = nil }
    private func resetSamples() { previous = nil; hasSample = false; rate = .zero; counters = nil; history.removeAll(keepingCapacity: true) }

    private func sample() {
        guard let current = selected, current.link == .connected, let new = reader.counters(current.name) else {
            resetSamples()
            onChange?()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        if let old = previous, old.name == current.name {
            rate = TrafficRate.between(old.sample, new, seconds: now - old.time)
            hasSample = true
            history.append(rate)
            if history.count > 60 { history.removeFirst(history.count - 60) }
        }
        previous = (current.name, new, now)
        counters = new
        onChange?()
    }
}
