# Implementation decisions

## Swift/AppKit and a small C bridge

AppKit supplies NSStatusItem and NSPopover directly. The panel is created lazily and released when closed, with native text fields, buttons, and an inexpensive custom graph. SwiftUI, a web view, Electron, and third-party chart libraries are unnecessary for this size of UI. Swift's size optimization, linker dead stripping, and symbol stripping reduce the release binary; AppKit/Swift frameworks are provided by macOS rather than bundled.

Rust was considered. It could implement counter sampling without a garbage collector, but this part of the app already uses a C syscall into a stack-allocated buffer. The UI would still require AppKit through Objective-C FFI and bindings such as [objc2-app-kit](https://docs.rs/objc2-app-kit/latest/objc2_app_kit/). That adds dependencies and bridge/ownership code without avoiding the native UI framework's memory cost. There is no demonstrated Rust performance improvement here, and no comparative Rust benchmark was claimed. The measured Swift/AppKit implementation is the simpler choice.

## Event-driven idle behavior

SystemConfiguration's SCDynamicStore subscriptions watch interface link/address changes, interface additions, and global IPv4/IPv6 route changes. Updates run on the main queue. Normal operation has **no periodic application timer while the panel is closed**. Sleep cancels the visible sampler; wake refreshes state and starts it only if the panel is still visible.

If subscribing fails, a 60-second timer with 10 seconds of scheduling tolerance acts as a fallback and the panel reports that fact. Otherwise a single DispatchSourceTimer samples once per second only with the panel open, with 150 ms of leeway. There are no one-second background redraws. The menu-bar glyph changes only when its connection state changes.

## Physical media and routes

SCNetworkInterfaceCopyAll discovers Ethernet-class interfaces. A read-only SIOCGIFMEDIA ioctl distinguishes a confirmed active physical link from merely having IFF_UP/IFF_RUNNING flags. It returns the negotiated media and duplex. Its temporary socket is a local control handle; it never calls connect, send, or recv. The app never changes network configuration.

SystemConfiguration's global PrimaryInterface values identify the default IPv4 and IPv6 paths. A physical Ethernet link can exist while Wi-Fi or a VPN is the default. The app displays those states separately. This is route information, not an active internet reachability test.

## Counters

The C helper reads the selected interface's IFMIB_IFDATA / IFDATA_GENERAL data directly into an ifmibdata structure on the stack. This avoids a heap-allocated dump of every route/interface. Counters are 64-bit. On the test Mac, NET_RT_IFLIST2 returned received bytes modulo 2^32 even though the returned structure had 64-bit fields; IFDATA_GENERAL matched netstat's full value exactly. That real-world check changed the implementation.

Rates use the actual monotonic elapsed time, rather than assuming the timer fires at exactly one second. A counter reset or a long wake/scheduling gap clears the computed rate to avoid negative rates or spikes. Changing adapters or closing the panel resets its sampler. No packets are generated, intercepted, or slowed by the measurement.

## Sources

- [Apple: NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Apple: SCDynamicStoreSetNotificationKeys](https://developer.apple.com/documentation/systemconfiguration/scdynamicstoresetnotificationkeys(_:_:_:))
- [Apple: DispatchSourceTimer](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer)
- [Apple: ifmibdata](https://developer.apple.com/documentation/kernel/ifmibdata)
- Darwin headers supplied by the local macOS SDK: net/if_media.h, net/if_mib.h, sys/resource.h.
