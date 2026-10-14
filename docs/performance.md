# Performance

Version 1.0.2, measured on 14 October 2026 on an Apple M4 Mac Mini running macOS 26.3.1. CPU is the average percentage of one core. Memory is median physical footprint in decimal MB.

| State | CPU | Memory | Duration |
| --- | ---: | ---: | ---: |
| Fresh launch, panel closed | 0.0438% | 12.42 MB | 20.196 s |
| Panel closed after use | 0.0060% | 29.95 MB | 20.186 s |

The fresh-launch interval includes startup work. These measurements describe one machine and are not a comparison between releases.

The ARM64 executable is 195,216 bytes. A benchmark completed 10,000 local counter reads in 138.106 ms: 13.811 µs per read, with all reads successful. This measures API cost, not network throughput.

## Validation

Nine tests cover counter arithmetic, resets, display units, link/route distinctions, adapter filtering, disconnects, removal, reconnection, and selected MAC addresses. The installed app's MAC and link values matched macOS interface data. Address hiding and adapter filtering were checked in the panel. The release signature and static analysis passed.

## Reproduction

Run the release app with the panel closed, then measure without opening or inspecting it during the interval:

```sh
python3 scripts/profile.py "$(pgrep -x WiredStatus)" --seconds 20 --label idle
dist/WiredStatus.app/Contents/MacOS/WiredStatus --benchmark
```

The profiler reads `proc_pid_rusage` counters and converts Mach time using `mach_timebase_info`. It is not bundled with the app. Measurement files remain in the Git-ignored `local-metrics/` directory.
