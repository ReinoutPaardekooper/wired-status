#ifndef WIRED_NETWORK_CORE_H
#define WIRED_NETWORK_CORE_H
#include <stdint.h>

typedef struct {
    int link;                /* -1 unknown, 0 disconnected, 1 connected */
    int full_duplex;         /* -1 unknown, 0 half, 1 full */
    uint64_t speed_bps;      /* zero when unsupported or disconnected */
} WSLink;

typedef struct {
    uint64_t received_bytes;
    uint64_t sent_bytes;
    uint64_t input_errors;
    uint64_t output_errors;
    uint64_t input_drops;
} WSCounters;

/* Queries only: these calls never send network packets or modify interfaces. */
WSLink ws_link(const char *name);
int ws_counters(const char *name, WSCounters *out);
#endif
