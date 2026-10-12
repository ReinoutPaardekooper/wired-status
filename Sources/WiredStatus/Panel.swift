import AppKit
import ServiceManagement

private extension NSTextField {
    func updateText(_ value: String) {
        if stringValue != value { stringValue = value }
    }
}

private func text(_ value: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let field = NSTextField(labelWithString: value)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.lineBreakMode = .byTruncatingMiddle
    field.maximumNumberOfLines = 1
    return field
}

private final class TrafficGraph: NSView {
    var samples: [TrafficRate] = [] { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let box = bounds.insetBy(dx: 1, dy: 4)
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        let grid = NSBezierPath()
        for part in [0.0, 0.5, 1.0] {
            let y = box.minY + box.height * part
            grid.move(to: NSPoint(x: box.minX, y: y)); grid.line(to: NSPoint(x: box.maxX, y: y))
        }
        grid.lineWidth = 0.5; grid.stroke()
        guard samples.count > 1 else { return }
        let peak = max(1_000_000, samples.map { max($0.down, $0.up) }.max() ?? 0)
        for (key, color) in [(\TrafficRate.down, NSColor.systemBlue), (\TrafficRate.up, NSColor.systemTeal)] {
            let path = NSBezierPath()
            for (i, sample) in samples.enumerated() {
                let x = box.minX + box.width * Double(60 - samples.count + i) / 59
                let y = box.maxY - box.height * sample[keyPath: key] / peak
                let point = NSPoint(x: x, y: y)
                if i == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            color.setStroke(); path.lineWidth = 1.5; path.stroke()
        }
    }
}

final class Panel: NSViewController {
    let monitor: Monitor
    private let state = text("Ethernet", size: 19, weight: .semibold)
    private let detail = text("", size: 12, color: .secondaryLabelColor)
    private let picker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let down = text("—", size: 23, weight: .medium)
    private let up = text("—", size: 23, weight: .medium)
    private let graph = TrafficGraph()
    private let graphNote = text("Traffic sampled while this panel is open", size: 11, color: .secondaryLabelColor)
    private var fields: [String: NSTextField] = [:]
    private var pickerNames: [String] = []
    private let hideAddresses = NSButton(checkboxWithTitle: "Hide addresses", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let notice = text("", size: 11, color: .secondaryLabelColor)
    private var loginMessage: String?

    init(monitor: Monitor) { self.monitor = monitor; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 610))
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
                                     stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
                                     stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20)])
        func full(_ view: NSView) {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        full(state); full(detail)
        picker.target = self; picker.action = #selector(selectInterface)
        picker.setAccessibilityLabel("Ethernet adapter")
        full(picker)
        full(separator())
        let traffic = NSStackView()
        traffic.orientation = .horizontal; traffic.distribution = .fillEqually; traffic.spacing = 16
        for (label, value, color) in [("↓ Download", down, NSColor.systemBlue), ("↑ Upload", up, NSColor.systemTeal)] {
            let column = NSStackView(views: [text(label, size: 12, weight: .medium, color: color), value])
            column.orientation = .vertical; column.alignment = .leading; column.spacing = 5
            value.font = .monospacedDigitSystemFont(ofSize: 23, weight: .medium)
            traffic.addArrangedSubview(column)
        }
        full(traffic)
        graph.heightAnchor.constraint(equalToConstant: 40).isActive = true
        graph.setAccessibilityLabel("Recent download and upload traffic, up to 60 seconds")
        full(graph); full(graphNote)
        full(separator())
        for key in ["Link speed", "Duplex", "Default route", "Local IPv4", "Local IPv6", "Router"] { full(row(key)) }
        full(separator())
        full(text("INTERFACE COUNTERS", size: 10, weight: .semibold, color: .secondaryLabelColor))
        for key in ["Received / sent", "Receive / send errors", "Receive drops"] { full(row(key)) }
        full(text("Since interface reset · errors are not an internet loss test", size: 10, color: .secondaryLabelColor))
        full(separator())
        hideAddresses.state = UserDefaults.standard.object(forKey: "hideAddresses") as? Bool == false ? .off : .on
        hideAddresses.target = self; hideAddresses.action = #selector(togglePrivacy)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self; login.action = #selector(toggleLogin)
        let options = NSStackView(views: [hideAddresses, login]); options.spacing = 16
        full(options)
        let footer = NSStackView(); footer.spacing = 8
        footer.addArrangedSubview(text("Local monitoring · no test traffic", size: 11, color: .secondaryLabelColor))
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); footer.addArrangedSubview(spacer)
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.bezelStyle = .rounded; footer.addArrangedSubview(quit)
        full(footer); full(notice)
        stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -12).isActive = true
        view = root
        refresh()
    }

    private func separator() -> NSView {
        let box = NSBox(); box.boxType = .separator
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    private func row(_ key: String) -> NSView {
        let label = text(key, size: 12, color: .secondaryLabelColor)
        let value = text("—", size: 12, weight: .medium)
        value.isSelectable = true
        value.setAccessibilityLabel(key)
        value.alignment = .right
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fields[key] = value
        let row = NSStackView(views: [label, value]); row.spacing = 8
        label.widthAnchor.constraint(equalToConstant: 123).isActive = true
        value.widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        row.distribution = .fill
        return row
    }

    func refresh() {
        guard isViewLoaded else { return }
        let names = monitor.interfaces.map(\.name)
        if names != pickerNames {
            picker.removeAllItems()
            for item in monitor.interfaces { picker.addItem(withTitle: "\(item.displayName) · \(item.name)") }
            if names.isEmpty { picker.addItem(withTitle: "No Ethernet adapters") }
            pickerNames = names
        }
        picker.isEnabled = names.count > 1
        let item = monitor.selected
        if let index = names.firstIndex(of: item?.name ?? "") { picker.selectItem(at: index) }
        switch item?.link {
        case .connected: state.updateText("Ethernet connected"); state.textColor = .labelColor
        case .disconnected: state.updateText("Cable disconnected"); state.textColor = .secondaryLabelColor
        default: state.updateText(item == nil ? "No Ethernet adapter" : "Link status unavailable"); state.textColor = .secondaryLabelColor
        }
        let isDefault = item?.primaryIPv4 == true || item?.primaryIPv6 == true
        detail.updateText(item?.link == .connected ? (isDefault ? "Your Mac is using this wired connection" : "Cable linked; the default route uses another interface") : "Connect an Ethernet cable to get started")
        let sampling = item?.link == .connected && !monitor.hasSample
        down.updateText(sampling ? "Sampling…" : MetricFormat.rate(monitor.rate.down))
        up.updateText(sampling ? "Sampling…" : MetricFormat.rate(monitor.rate.up))
        graph.samples = monitor.history
        graphNote.updateText("Live traffic · ~\(monitor.history.count)s shown · auto-scaled")
        fields["Link speed"]?.updateText(item.map { MetricFormat.speed($0.speedBps) } ?? "—")
        fields["Duplex"]?.updateText(item?.link == .connected ? item?.duplex ?? "—" : "—")
        fields["Default route"]?.updateText(MetricFormat.route(item, primary4: monitor.primary4, primary6: monitor.primary6))
        let hidden = hideAddresses.state == .on
        fields["Local IPv4"]?.updateText(address(item?.ipv4 ?? [], hidden: hidden))
        fields["Local IPv6"]?.updateText(address(item?.ipv6 ?? [], hidden: hidden))
        fields["Router"]?.updateText(address(item?.router.map { [$0] } ?? [], hidden: hidden))
        if let c = monitor.counters {
            fields["Received / sent"]?.updateText("\(MetricFormat.bytes(c.received)) / \(MetricFormat.bytes(c.sent))")
            fields["Receive / send errors"]?.updateText("\(c.errorsIn) / \(c.errorsOut)")
            fields["Receive drops"]?.updateText("\(c.dropsIn)")
        } else {
            ["Received / sent", "Receive / send errors", "Receive drops"].forEach { fields[$0]?.updateText("—") }
        }
        for field in fields.values where field.toolTip != field.stringValue { field.toolTip = field.stringValue }
        notice.updateText(loginMessage ?? (monitor.notificationsWorking ? "" : "Network events unavailable; idle refresh every 60 seconds."))
    }

    private func address(_ values: [String], hidden: Bool) -> String {
        guard !values.isEmpty else { return "Not assigned" }
        return hidden ? "Hidden" : values.joined(separator: ", ")
    }
    @objc private func selectInterface() {
        guard pickerNames.indices.contains(picker.indexOfSelectedItem) else { return }
        monitor.choose(pickerNames[picker.indexOfSelectedItem])
    }
    @objc private func togglePrivacy() {
        UserDefaults.standard.set(hideAddresses.state == .on, forKey: "hideAddresses")
        refresh()
    }
    @objc private func toggleLogin() {
        loginMessage = nil
        do {
            if login.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            if SMAppService.mainApp.status == .requiresApproval { loginMessage = "Enable WiredStatus in System Settings → Login Items." }
        } catch {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            loginMessage = "Could not update login setting: \(error.localizedDescription)"
        }
        refresh()
    }
}
