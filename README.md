# WiredStatus

A small, native Ethernet indicator for the macOS menu bar. Built from scratch in Swift/AppKit and C, using only macOS APIs. No packages to install, accounts, analytics, servers, packet capture, or automatic speed tests.

## What you see

- An Ethernet icon in the menu bar. A slash means no confirmed cable link; a dot means a cable is linked but the selected adapter is not the default network route.
- Negotiated link speed and duplex, including 1, 2.5, 5, and 10 Gbps Ethernet.
- Live receive/send rates and a 60-second graph, sampled only while the panel is open.
- Separate physical-link and default-route status for IPv4 and IPv6. A VPN or Wi-Fi default route is named rather than silently called Ethernet.
- Local addresses, hidden by default, and interface byte/error/drop counters.
- A native optional Open at login setting and support for multiple adapters.

Link speed is the Ethernet connection's capacity, **not** an internet speed test. Live rates count all traffic on the selected adapter, including local-network traffic. The graph auto-scales; it isn't a percentage of the link's capacity. Interface errors are cumulative driver counters since reset and aren't an end-to-end packet-loss measurement.

## Screenshots

Captured from the app running on a real Mac. Addresses are hidden using its privacy setting. The disconnected screenshot selects an unused adapter; the active connection was not unplugged.

| Connected | Disconnected |
| --- | --- |
| <img src="docs/screenshots/connected.jpg" alt="Connected Ethernet and live metrics" width="390"> | <img src="docs/screenshots/disconnected.jpg" alt="Disconnected adapter" width="390"> |

## Build and run

Requires macOS 13 or newer and Xcode or its command-line tools with Swift 5.10 or newer. Build on either an Apple Silicon or Intel Mac; the result targets the build machine's architecture.

```sh
./scripts/build.sh
open dist/WiredStatus.app
```

The release script applies a local ad-hoc signature. No signing keys or Apple developer membership are needed to build locally. It isn't a notarized public download. On another Mac, build from this source using the instructions above.

To install the locally built app:

```sh
mkdir -p "$HOME/Applications"
ditto dist/WiredStatus.app "$HOME/Applications/WiredStatus.app"
open "$HOME/Applications/WiredStatus.app"
```

The app stays out of the Dock. Click its menu-bar icon to open the panel. Open at login is opt-in. Quit from the panel before rebuilding or replacing an installed copy.

A locally built Apple Silicon app is also attached to this private repository's [v1.0.0 release](https://github.com/ReinoutPaardekooper/wired-status/releases/tag/v1.0.0), with its SHA-256 checksum. The source build remains the inspectable way to reproduce it. No automatic updater contacts GitHub.

## Verify

```sh
swift test
dist/WiredStatus.app/Contents/MacOS/WiredStatus --diagnostics
dist/WiredStatus.app/Contents/MacOS/WiredStatus --benchmark
```

`--diagnostics` prints current local interface data, including addresses, to the terminal. Neither CLI mode contacts a server. `--benchmark` repeatedly reads existing kernel counters; it measures the cost of the app's sampling API, not network speed.

See [performance measurements and method](docs/performance.md) and [implementation decisions](docs/design.md). Generated builds and local measurement data are excluded from Git. There are no external dependencies, so no dependency lockfile is required.

## Privacy and practical limits

Network configuration, physical link state, and counters are read locally. The only persistent settings are the selected adapter and address-visibility preference in macOS UserDefaults; Open at login uses Apple's ServiceManagement API. No traffic history is saved to disk. The tiny graph is bounded to 60 in-memory samples and clears when the panel closes.

The indicator does not prove that the router or internet is reachable. Unknown or unsupported link modes are shown as unavailable rather than guessed. Some drivers may not maintain useful error counters. A driver can reset counters when a device reconnects. Errors from earlier activity do not establish that a newly installed cable is faulty. Use normal network diagnostics if connectivity is lost.
