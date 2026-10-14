# Performance and validation

Version 1.0.0 baseline, measured locally on 12 October 2026: Apple M4 Mac Mini, macOS 26.3.1, Swift 6.3.3. The selected Ethernet adapter reported a real 1 Gbps full-duplex link and was the default IPv4 and IPv6 interface. Version 1.0.1 changes only the menu-bar glyph and saved-position support; its sampling and network APIs are unchanged. The sizes and measurements below refer to the baseline build.

## Resource use

Release build with Swift size optimization, dead stripping, and stripped symbols. Each resource window lasted about 30 seconds. CPU is the average percentage of **one CPU core**, not total machine capacity. Memory is median physical footprint in decimal MB; RSS includes shared pages and is not interchangeable with footprint.

| State | CPU | Physical footprint | CPU time over ~30 s |
| --- | ---: | ---: | ---: |
| Fresh launch, icon idle | 0.0016% | 12.24 MB | 0.000499 s |
| Panel open, live traffic and graph | 0.4135% | 37.55 MB | 0.125448 s |
| Panel closed after use | 0.0031% | 38.59 MB | 0.000933 s |

The app releases its panel and graph on close. AppKit's warmed font, graphics, and accessibility caches still retain memory after first use; it would be misleading to claim the app always returns to its initial 12 MB. The sampler stops: package-idle wakeups decreased from 50 with the panel open to 2 after closing during these measurement windows. Native macOS notifications and framework work can still wake a closed app, so total wakeups are not promised to be zero.

The ARM64 executable is **178,608 bytes (~174.4 KiB)**. A 10,000-read local counter benchmark took **129.22 ms total, 12.92 µs per read**, with all reads successful. This is the sampling API cost, not an internet speed result. The normal panel performs one read per second, and no periodic reads while closed when notifications are available.

These are short measurements on one real Mac, not guarantees for every driver, macOS version, or workload. No comparative Rust benchmark was performed.

### Version 1.0.2 check

Measured on the same Mac on 14 October 2026. The MAC field and filtered picker add no dependencies, background timers, or network requests. Metadata is cached during existing configuration refreshes. The ARM64 executable is 195,216 bytes, 16,592 bytes larger than version 1.0.1. All 10,000 local counter reads succeeded in 138.106 ms, or 13.811 µs per read.

| State | CPU, one core | Physical footprint | Measurement window |
| --- | ---: | ---: | ---: |
| Fresh launch, icon idle | 0.0438% | 12.42 MB | 20.196 s |
| Panel closed after use | 0.0060% | 29.95 MB | 20.186 s |

The first window includes startup and framework work, so these short readings are not a before/after CPU comparison. The second window was confirmed to have a closed panel; a subsequent UI inspection reopened it with a fresh sampling baseline. The normal closed-panel sampler remains stopped.

Nine unit tests passed, including new cases for idle linked adapters, default routes with unknown driver link status, disconnection, removal, preferred-adapter reconnection, and selecting the matching adapter's MAC. The reported MAC matched the selected interface in `ifconfig`. The installed app showed only the one adapter in use out of seven discovered interfaces, preserved its login setting, and hid MAC/IP/router fields when Hide addresses was enabled. The current connected screenshot shows this release; the disconnected screenshot retained in the repository is an earlier baseline image.

## Why this avoids consuming bandwidth

The app reads existing kernel counters and SystemConfiguration data. It doesn't send probes, run speed tests, capture packets, create a proxy/VPN/filter, or sit in the packet forwarding path. Reviewing every source file found no backend URLs, HTTP clients, connect/send/recv calls, subprocess-based network tools, or packet-capture code. `lsof` found no TCP/UDP network connections owned by the live app, both while open and after closing. The SIOCGIFMEDIA helper opens a temporary local ioctl handle without sending anything.

This validates the absence of app-generated test traffic and its low processing cost. It is not a claim that an A/B ISP speed experiment was performed; speed-test variation would not isolate the tiny cost of a passive read. Monitoring does not consume a share of the plan's advertised Mbps.

## Metric correctness and GUI checks

- The physical-link API's 1,000,000,000 bps and full-duplex result matched `ifconfig`.
- The received-byte counter exceeded 6 GB and matched `netstat` exactly; this exposed and avoided a 32-bit truncation in the alternative routing-statistics API.
- Both default routes matched the active Ethernet interface. The primary IPv4 router is read from the global configuration when absent from the interface dictionary.
- Five unit tests passed, covering large byte totals, actual elapsed time, resets/wake gaps, display units, unavailable interfaces, and cable-link/default-route distinctions.
- Clang static analysis of the C helper completed without findings. The packaged app's local signature verified.
- Real GUI checks covered opening/reopening, connected metrics, switching to an unused disconnected adapter, restoring the active adapter, and closing. Closing was measured without invoking UI inspection, because the inspection tool itself sends a Launch Services reopen event.
- Both screenshots were captured from the final installed app. Addresses were hidden, and the disconnected view used an existing unused adapter instead of disrupting internet access.

## Reproduce

Build and open the release app, then run:

```sh
python3 scripts/profile.py "$(pgrep -x WiredStatus)" --seconds 30 --label idle
```

Repeat with the panel open, then close it and repeat without reopening or inspecting it during that interval. `scripts/resource-probe.c` reads process resource counters using proc_pid_rusage and converts CPU-duration mach ticks with mach_timebase_info. On Apple Silicon those values must not be treated directly as nanoseconds. The helper is only a development tool and is not bundled with the app.

```sh
dist/WiredStatus.app/Contents/MacOS/WiredStatus --benchmark
dist/WiredStatus.app/Contents/MacOS/WiredStatus --diagnostics
netstat -bI en0
ifconfig en0
lsof -nP -a -p "$(pgrep -x WiredStatus)" -i
```

`--diagnostics`, `netstat`, and `ifconfig` print local addresses; keep those outputs private. `lsof` returns no lines (and exit status 1) when no matching sockets exist. Local measurement JSON and generated probe binaries stay in the ignored `local-metrics/` folder.
