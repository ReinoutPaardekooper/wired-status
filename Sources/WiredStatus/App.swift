import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var status: NSStatusItem!
    private let monitor = Monitor()
    private var panel: Panel?
    private var popover: NSPopover?
    private var lastIconState = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.autosaveName = NSStatusItem.AutosaveName("WiredStatus")
        status.button?.target = self
        status.button?.action = #selector(toggle)
        monitor.onChange = { [weak self] in self?.update() }
        update()
    }

    private func update() {
        let item = monitor.selected
        let isDefault = item?.primaryIPv4 == true || item?.primaryIPv6 == true
        let state = "\(item?.link.rawValue ?? "none")-\(isDefault)"
        if state != lastIconState {
            status?.button?.image = ethernetIcon(link: item?.link, isDefault: isDefault)
            lastIconState = state
        }
        let title = item?.link == .connected ? "Ethernet · \(MetricFormat.speed(item?.speedBps ?? 0))" : "Ethernet disconnected"
        status?.button?.toolTip = title
        status?.button?.setAccessibilityLabel(title)
        if monitor.isVisible { panel?.refresh() }
    }

    @objc private func toggle() {
        guard let button = status.button else { return }
        if popover?.isShown == true { popover?.performClose(nil); return }
        if panel == nil {
            let controller = Panel(monitor: monitor)
            let p = NSPopover(); p.behavior = .transient; p.animates = false
            p.contentViewController = controller; p.delegate = self
            p.contentSize = NSSize(width: 390, height: 610)
            panel = controller; popover = p
        }
        monitor.show()
        NSApp.activate(ignoringOtherApps: true)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    func popoverDidClose(_ notification: Notification) {
        monitor.hide()
        // Release the text controls and graph while the menu-bar icon is idle.
        panel = nil
        popover = nil
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launch Services also sends reopen events when inspecting an accessory
        // app. Reopening must be idempotent, unlike clicking the menu-bar button.
        if popover?.isShown != true { toggle() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.hide() }
}

@main
enum WiredStatusMain {
    static func main() {
        if CommandLine.arguments.contains("--benchmark") {
            let reader = NetworkReader()
            guard let selected = reader.interfaces().first(where: { $0.link == .connected }) else {
                print("No connected Ethernet interface to benchmark.")
                return
            }
            let iterations = 10_000
            let start = ProcessInfo.processInfo.systemUptime
            var successful = 0
            for _ in 0..<iterations { if reader.counters(selected.name) != nil { successful += 1 } }
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            print(String(format: "%d/%d local counter reads; %.3f µs/read; %.3f ms total",
                         successful, iterations, elapsed * 1e6 / Double(iterations), elapsed * 1000))
            return
        }
        if CommandLine.arguments.contains("--diagnostics") {
            let reader = NetworkReader()
            struct Diagnostic: Codable {
                var interfaces: [InterfaceSnapshot]
                var counters: [String: CounterSample]
            }
            let list = reader.interfaces()
            let counts = Dictionary(uniqueKeysWithValues: list.compactMap { item in reader.counters(item.name).map { (item.name, $0) } })
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(Diagnostic(interfaces: list, counters: counts)) { print(String(decoding: data, as: UTF8.self)) }
            return
        }
        if let id = Bundle.main.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            running.activate(options: [])
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
