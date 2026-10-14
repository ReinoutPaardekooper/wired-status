# Architecture

## Interface

`NSStatusItem` provides the menu-bar icon. The `NSPopover` panel is created on demand and released when closed. Its graph retains at most 60 samples.

## Data sources

| Data | Local API |
| --- | --- |
| Ethernet interfaces and MAC addresses | `SCNetworkInterfaceCopyAll`, `SCNetworkInterfaceGetHardwareAddressString` |
| IP addresses and default routes | `SCDynamicStoreCopyValue` |
| Physical link, negotiated speed, and duplex | `SIOCGIFMEDIA` |
| Byte, error, and drop counters | `sysctl` with `IFMIB_IFDATA` / `IFDATA_GENERAL` |

Metadata and adapter choices are cached during configuration refreshes. The picker includes linked or default-route Ethernet interfaces, regardless of traffic activity. An unavailable preferred adapter yields to an adapter in use and is restored on reconnect. If none are in use, one disconnected selection remains; removed adapters fall back to an existing interface.

The MAC field belongs to the selected Ethernet interface. Hide addresses replaces displayed address text and tooltips with "Hidden".

## Scheduling

`SCDynamicStore` notifications refresh configuration on the main queue. A one-second timer reads counters only while the panel is open. If notification subscription fails, configuration refreshes every 60 seconds. Sleep stops sampling; wake refreshes configuration and resumes sampling only for an open panel.

Rates use 64-bit counter differences and monotonic elapsed time. Counter resets, invalid intervals, or intervals of 10 seconds or longer yield zero rates. Adapter changes and panel closure clear the sampling baseline and history.

The link query uses a temporary socket for a read-only ioctl. No packets are sent and network configuration is not modified.
