import Foundation
import SystemConfiguration
import NetworkCore

final class NetworkReader {
    let store: SCDynamicStore?
    init(store: SCDynamicStore? = nil) {
        self.store = store ?? SCDynamicStoreCreate(nil, "WiredStatus.Read" as CFString, nil, nil)
    }

    func dictionary(_ key: String) -> [String: Any] {
        guard let store else { return [:] }
        return SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any] ?? [:]
    }

    var primary4: String? { dictionary("State:/Network/Global/IPv4")["PrimaryInterface"] as? String }
    var primary6: String? { dictionary("State:/Network/Global/IPv6")["PrimaryInterface"] as? String }

    func interfaces() -> [InterfaceSnapshot] {
        guard let list = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [] }
        let global4 = dictionary("State:/Network/Global/IPv4")
        let p4 = global4["PrimaryInterface"] as? String, p6 = primary6
        var names = Set<String>()
        return list.compactMap { interface -> InterfaceSnapshot? in
            guard SCNetworkInterfaceGetInterfaceType(interface) as String? == kSCNetworkInterfaceTypeEthernet as String,
                  let name = SCNetworkInterfaceGetBSDName(interface) as String?, names.insert(name).inserted else { return nil }
            let media = name.withCString { ws_link($0) }
            let v4 = dictionary("State:/Network/Interface/\(name)/IPv4")
            let v6 = dictionary("State:/Network/Interface/\(name)/IPv6")
            let label = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? ?? "Ethernet"
            return InterfaceSnapshot(name: name, displayName: label,
                                     link: media.link == 1 ? .connected : media.link == 0 ? .disconnected : .unknown,
                                     speedBps: media.speed_bps,
                                     duplex: media.full_duplex == 1 ? "Full duplex" : media.full_duplex == 0 ? "Half duplex" : "Unavailable",
                                     ipv4: v4["Addresses"] as? [String] ?? [],
                                     ipv6: v6["Addresses"] as? [String] ?? [],
                                     router: v4["Router"] as? String ?? (name == p4 ? global4["Router"] as? String : nil),
                                     primaryIPv4: name == p4, primaryIPv6: name == p6)
        }.sorted {
            let a = ($0.primaryIPv4 ? 4 : 0) + ($0.primaryIPv6 ? 2 : 0) + ($0.link == .connected ? 1 : 0)
            let b = ($1.primaryIPv4 ? 4 : 0) + ($1.primaryIPv6 ? 2 : 0) + ($1.link == .connected ? 1 : 0)
            return a == b ? $0.name < $1.name : a > b
        }
    }

    func counters(_ name: String) -> CounterSample? {
        var raw = WSCounters()
        guard name.withCString({ ws_counters($0, &raw) }) == 1 else { return nil }
        return CounterSample(received: raw.received_bytes, sent: raw.sent_bytes,
                             errorsIn: raw.input_errors, errorsOut: raw.output_errors, dropsIn: raw.input_drops)
    }
}
