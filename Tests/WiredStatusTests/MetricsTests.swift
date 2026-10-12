import XCTest
@testable import WiredStatus
import NetworkCore

final class MetricsTests: XCTestCase {
    func testLarge64BitCountersAndActualElapsedTime() {
        let old = CounterSample(received: 6_000_000_000, sent: 5_000_000_000, errorsIn: 0, errorsOut: 0, dropsIn: 0)
        var new = old; new.received += 125_000_000; new.sent += 12_500_000
        XCTAssertEqual(TrafficRate.between(old, new, seconds: 2), TrafficRate(down: 500_000_000, up: 50_000_000))
    }
    func testCounterResetAndWakeGapDoNotProduceSpikes() {
        let a = CounterSample(received: 1000, sent: 500, errorsIn: 0, errorsOut: 0, dropsIn: 0)
        let b = CounterSample(received: 10, sent: 5, errorsIn: 0, errorsOut: 0, dropsIn: 0)
        XCTAssertEqual(TrafficRate.between(a, b, seconds: 1), .zero)
        XCTAssertEqual(TrafficRate.between(b, a, seconds: 60), .zero)
        XCTAssertEqual(TrafficRate.between(b, a, seconds: 0), .zero)
        XCTAssertEqual(TrafficRate.between(b, a, seconds: .infinity), .zero)
    }
    func testNegotiatedSpeeds() {
        XCTAssertEqual(MetricFormat.speed(100_000_000), "100 Mbps")
        XCTAssertEqual(MetricFormat.speed(1_000_000_000), "1 Gbps")
        XCTAssertEqual(MetricFormat.speed(2_500_000_000), "2.5 Gbps")
        XCTAssertEqual(MetricFormat.speed(0), "Unavailable")
    }
    func testUnknownInterfaceDoesNotInventConnectionOrCounters() {
        XCTAssertEqual("notaninterface".withCString { ws_link($0) }.link, -1)
        var raw = WSCounters()
        XCTAssertEqual("notaninterface".withCString { ws_counters($0, &raw) }, 0)
    }
    func testConnectedCableIsDifferentFromDefaultRoute() {
        var item = InterfaceSnapshot(name: "en0", displayName: "Ethernet", link: .connected, speedBps: 1_000_000_000,
                                     duplex: "Full duplex", ipv4: [], ipv6: [], router: nil, primaryIPv4: false, primaryIPv6: false)
        XCTAssertEqual(MetricFormat.route(item, primary4: "utun3", primary6: "en1"), "Default uses en1, utun3")
        item.primaryIPv4 = true
        XCTAssertEqual(MetricFormat.route(item, primary4: "en0", primary6: "en1"), "Default for IPv4")
        item.primaryIPv6 = true
        XCTAssertEqual(MetricFormat.route(item, primary4: "en0", primary6: "en0"), "Default for IPv4 & IPv6")
        item.link = .disconnected
        XCTAssertEqual(MetricFormat.route(item, primary4: nil, primary6: nil), "No cable link")
    }
}
