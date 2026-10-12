/* Developer measurement tool; not linked into the app. */
#include <libproc.h>
#include <sys/resource.h>
#include <stdio.h>
#include <stdlib.h>
#include <mach/mach_time.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    struct rusage_info_v4 info = {0};
    if (proc_pid_rusage(atoi(argv[1]), RUSAGE_INFO_V4, (rusage_info_t *)&info)) return 1;
    mach_timebase_info_data_t clock;
    mach_timebase_info(&clock);
    // rusage CPU durations are mach absolute ticks, not nanoseconds on Apple Silicon.
    double cpu_ns = (double)(info.ri_user_time + info.ri_system_time) * clock.numer / clock.denom;
    printf("{\"cpu_ns\":%.0f,\"footprint_bytes\":%llu,\"rss_bytes\":%llu,\"idle_wakeups\":%llu,\"interrupt_wakeups\":%llu}\n",
           cpu_ns, info.ri_phys_footprint, info.ri_resident_size,
           info.ri_pkg_idle_wkups, info.ri_interrupt_wkups);
}
