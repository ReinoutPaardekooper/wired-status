import XCTest
@testable import WiredStatus

final class InterfaceSelectionTests: XCTestCase {
    private func adapter(_ name: String, link: LinkState = .disconnected, primary: Bool = false, mac: String? = nil) -> InterfaceSnapshot {
        InterfaceSnapshot(name: name, displayName: "Test Ethernet", link: link, speedBps: 1_000_000_000,
                          duplex: "Full duplex", ipv4: [], ipv6: [], router: nil,
                          primaryIPv4: primary, primaryIPv6: false, macAddress: mac)
    }

    func testQuietLinkedAdaptersStayVisibleAndUnusedSavedChoiceIsSkipped() {
        let main = adapter("wired-main", link: .connected, primary: true)
        let peer = adapter("wired-peer", link: .connected)
        let unused = adapter("unused-usb")
        let all = [main, unused, peer]
        let selected = InterfaceSelection.selected(from: all, preferredName: unused.name, previousName: unused.name)
        XCTAssertEqual(selected?.name, main.name)
        XCTAssertEqual(InterfaceSelection.visible(from: all, selectedName: selected?.name).map(\.name), [main.name, peer.name])
    }

    func testDisconnectKeepsLastAdapterAndRemovedAdaptersCannotLeaveAStaleSelection() {
        let unused = adapter("unused-usb")
        let dropped = adapter("wired-main")
        let all = [unused, dropped]
        let selected = InterfaceSelection.selected(from: all, preferredName: nil, previousName: dropped.name)
        XCTAssertEqual(selected?.name, dropped.name)
        XCTAssertEqual(InterfaceSelection.visible(from: all, selectedName: selected?.name).map(\.name), [dropped.name])

        let remaining = InterfaceSelection.selected(from: [unused], preferredName: dropped.name, previousName: dropped.name)
        XCTAssertEqual(remaining?.name, unused.name)
        XCTAssertNil(InterfaceSelection.selected(from: [], preferredName: dropped.name, previousName: dropped.name))
        XCTAssertTrue(InterfaceSelection.visible(from: [], selectedName: dropped.name).isEmpty)
    }

    func testDefaultRouteWithUnknownDriverLinkStatusRemainsSelectable() {
        let unavailable = adapter("unused-usb")
        let defaultRoute = adapter("wired-main", link: .unknown, primary: true)
        let all = [defaultRoute, unavailable]
        let selected = InterfaceSelection.selected(from: all, preferredName: unavailable.name, previousName: nil)
        XCTAssertEqual(selected?.name, defaultRoute.name)
        XCTAssertEqual(InterfaceSelection.visible(from: all, selectedName: selected?.name).map(\.name), [defaultRoute.name])
    }

    func testFallbackAndReconnectReturnTheSelectedAdaptersOwnMAC() {
        // Synthetic locally administered addresses, not real device identities.
        let main = adapter("wired-main", link: .connected, primary: true, mac: "02:00:00:00:00:01")
        var dock = adapter("wired-dock", mac: "02:00:00:00:00:02")
        let fallback = InterfaceSelection.selected(from: [main, dock], preferredName: dock.name, previousName: dock.name)
        XCTAssertEqual(fallback?.name, main.name)
        XCTAssertEqual(fallback?.macAddress, main.macAddress)

        dock.link = .connected
        let restored = InterfaceSelection.selected(from: [main, dock], preferredName: dock.name, previousName: main.name)
        XCTAssertEqual(restored?.name, dock.name)
        XCTAssertEqual(restored?.macAddress, dock.macAddress)
        XCTAssertEqual(InterfaceSelection.visible(from: [main, dock], selectedName: restored?.name).count, 2)
    }
}
