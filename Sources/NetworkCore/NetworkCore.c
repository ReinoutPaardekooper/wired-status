#include "NetworkCore.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/if_media.h>
#include <net/if_mib.h>
#include <string.h>
#include <unistd.h>

static uint64_t media_speed(int media) {
    if (IFM_TYPE(media) != IFM_ETHER) return 0;
    switch (IFM_SUBTYPE(media)) {
        case IFM_10_T: case IFM_10_2: case IFM_10_5: case IFM_10_STP: case IFM_10_FL:
            return 10000000ULL;
        case IFM_100_TX: case IFM_100_FX: case IFM_100_T4: case IFM_100_VG: case IFM_100_T2:
            return 100000000ULL;
        case IFM_1000_T: case IFM_1000_SX: case IFM_1000_LX: case IFM_1000_CX:
        case IFM_1000_CX_SGMII: case IFM_1000_KX:
            return 1000000000ULL;
        case IFM_2500_T: return 2500000000ULL;
        case IFM_5000_T: return 5000000000ULL;
        case IFM_10G_T: case IFM_10G_SR: case IFM_10G_LR: case IFM_10G_CX4:
        case IFM_10G_KX4: case IFM_10G_KR: case IFM_10G_CR1: case IFM_10G_ER:
            return 10000000000ULL;
        default: return 0;   /* Do not invent a speed for an unknown driver mode. */
    }
}

WSLink ws_link(const char *name) {
    WSLink result = {-1, -1, 0};
    if (!name || strlen(name) >= IFNAMSIZ) return result;
    int fd = socket(AF_INET, SOCK_DGRAM, 0); /* Local ioctl handle; no connect/send. */
    if (fd < 0) return result;
    struct ifmediareq req = {0};
    strlcpy(req.ifm_name, name, sizeof(req.ifm_name));
    if (ioctl(fd, SIOCGIFMEDIA, &req) == 0 && (req.ifm_status & IFM_AVALID)) {
        result.link = (req.ifm_status & IFM_ACTIVE) ? 1 : 0;
        if (result.link == 1) {
            result.speed_bps = media_speed(req.ifm_active);
            result.full_duplex = (req.ifm_active & IFM_FDX) ? 1 : 0;
        }
    }
    close(fd);
    return result;
}

int ws_counters(const char *name, WSCounters *out) {
    if (!name || !out) return 0;
    memset(out, 0, sizeof(*out));
    unsigned int index = if_nametoindex(name);
    if (!index) return 0;
    // IFDATA_GENERAL provides accurate 64-bit counters. NET_RT_IFLIST2 on this
    // Mac returned RX modulo 2^32 even though its structure has 64-bit fields.
    // One syscall into a stack buffer also avoids allocating a routing dump.
    int mib[6] = {CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, (int)index, IFDATA_GENERAL};
    struct ifmibdata data = {0};
    size_t size = sizeof(data);
    if (sysctl(mib, 6, &data, &size, NULL, 0) != 0 || size < sizeof(data)) return 0;
    out->received_bytes = data.ifmd_data.ifi_ibytes;
    out->sent_bytes = data.ifmd_data.ifi_obytes;
    out->input_errors = data.ifmd_data.ifi_ierrors;
    out->output_errors = data.ifmd_data.ifi_oerrors;
    out->input_drops = data.ifmd_data.ifi_iqdrops;
    return 1;
}
