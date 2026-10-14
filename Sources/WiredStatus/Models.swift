import Foundation

enum LinkState: String, Codable { case connected, disconnected, unknown }

struct InterfaceSnapshot: Codable {
    var name: String
    var displayName: String
    var link: LinkState
    var speedBps: UInt64
    var duplex: String
    var ipv4: [String]
    var ipv6: [String]
    var router: String?
    var primaryIPv4: Bool
    var primaryIPv6: Bool
    var macAddress: String? = nil

    // A quiet cable is still in use. Keep a default-route adapter visible even
    // when its driver cannot report physical link state.
    var isInUse: Bool { link == .connected || primaryIPv4 || primaryIPv6 }
}

enum InterfaceSelection {
    static func selected(from interfaces: [InterfaceSnapshot], preferredName: String?, previousName: String?) -> InterfaceSnapshot? {
        let preferred = interfaces.first { $0.name == preferredName }
        if let preferred, preferred.isInUse { return preferred }
        if let active = interfaces.first(where: \.isInUse) { return active }
        // Keep the last adapter's disconnected state available. If it has been
        // physically removed, fall back to one that macOS still knows about.
        return interfaces.first { $0.name == previousName } ?? preferred ?? interfaces.first
    }

    static func visible(from interfaces: [InterfaceSnapshot], selectedName: String?) -> [InterfaceSnapshot] {
        interfaces.filter { $0.isInUse || $0.name == selectedName }
    }
}

struct CounterSample: Codable, Equatable {
    var received: UInt64
    var sent: UInt64
    var errorsIn: UInt64
    var errorsOut: UInt64
    var dropsIn: UInt64
}

struct TrafficRate: Equatable {
    let down: Double // bits per second
    let up: Double
    static let zero = TrafficRate(down: 0, up: 0)

    static func between(_ old: CounterSample, _ new: CounterSample, seconds: Double) -> TrafficRate {
        guard seconds > 0, seconds < 10, seconds.isFinite,
              new.received >= old.received, new.sent >= old.sent else { return .zero }
        return TrafficRate(down: Double(new.received - old.received) * 8 / seconds,
                           up: Double(new.sent - old.sent) * 8 / seconds)
    }
}

enum MetricFormat {
    static func speed(_ bps: UInt64) -> String {
        guard bps > 0 else { return "Unavailable" }
        if bps >= 1_000_000_000 { return String(format: "%.3g Gbps", Double(bps) / 1e9) }
        return String(format: "%.0f Mbps", Double(bps) / 1e6)
    }
    static func rate(_ bps: Double) -> String {
        let safe = max(0, bps.isFinite ? bps : 0)
        if safe >= 1e9 { return String(format: "%.2f Gbps", safe / 1e9) }
        return String(format: "%.2f Mbps", safe / 1e6)
    }
    static func bytes(_ count: UInt64) -> String {
        if count >= 1_000_000_000 { return String(format: "%.2f GB", Double(count) / 1e9) }
        return String(format: "%.1f MB", Double(count) / 1e6)
    }
    static func route(_ selected: InterfaceSnapshot?, primary4: String?, primary6: String?) -> String {
        guard let selected else { return "No Ethernet adapter" }
        guard selected.link == .connected else { return "No cable link" }
        if selected.primaryIPv4 && selected.primaryIPv6 { return "Default for IPv4 & IPv6" }
        if selected.primaryIPv4 { return "Default for IPv4" }
        if selected.primaryIPv6 { return "Default for IPv6" }
        let others = Array(Set([primary4, primary6].compactMap { $0 })).sorted()
        return others.isEmpty ? "No default route" : "Default uses \(others.joined(separator: ", "))"
    }
}
