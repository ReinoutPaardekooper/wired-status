# WiredStatus

Ethernet status monitor for the macOS menu bar.

## Features

- Negotiated link speed, duplex, and default IPv4/IPv6 route status.
- Selected adapter's MAC, local IP, and router addresses; hidden by default and selectable for copying.
- Receive/send rates, a bounded traffic graph, and cumulative interface counters.
- Selection of adapters with a cable link or default route, with a disconnected fallback when none are in use.
- Optional launch at login.

A slash through the icon indicates no confirmed cable link. A dot below it indicates a linked adapter that is not the default IPv4 or IPv6 route.

Link speed is connection capacity, not internet throughput. Traffic rates include local-network traffic. Interface errors are driver counters, not an end-to-end packet-loss measurement. Link and route status do not establish internet reachability.

## Screenshot

Version 1.0.2, with addresses hidden.

<img src="docs/screenshots/connected.jpg" alt="Ethernet status panel with addresses hidden" width="390">

## Build and install

Requirements: macOS 13 or later and Xcode or command-line tools with Swift 5.10 or later. Builds target the host architecture. There are no third-party dependencies.

```sh
./scripts/build.sh
mkdir -p "$HOME/Applications"
ditto dist/WiredStatus.app "$HOME/Applications/WiredStatus.app"
open "$HOME/Applications/WiredStatus.app"
```

Quit an existing instance before replacing the installed app. Click the menu-bar icon to open the panel. Hold Command and drag the icon to reposition it; its position persists across relaunches.

The [v1.0.2 release](https://github.com/ReinoutPaardekooper/wired-status/releases/tag/v1.0.2) includes an Apple Silicon build and checksum. The app is ad-hoc signed and not notarized. Intel Macs can build from source. Verify the archive beside its checksum file:

```sh
shasum -a 256 -c WiredStatus-arm64.sha256
```

## Monitoring and privacy

The app reads local interface configuration and counters. It sends no network requests and performs no packet capture. Sampling runs once per second while the panel is open. When closed, configuration updates use macOS notifications; a 60-second fallback applies if subscription fails.

Adapter selection and address visibility are stored in UserDefaults. Login registration uses ServiceManagement. Traffic history remains in memory and clears when the panel closes.

## Verification

```sh
swift test
dist/WiredStatus.app/Contents/MacOS/WiredStatus --diagnostics
dist/WiredStatus.app/Contents/MacOS/WiredStatus --benchmark
```

Diagnostics contain local MAC and IP addresses. The benchmark measures local counter reads, not network throughput.

See [architecture](docs/design.md) and [performance measurements](docs/performance.md).
