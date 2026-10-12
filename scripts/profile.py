#!/usr/bin/env python3
"""Read-only resource measurement. Does not generate traffic or change networks."""
import argparse
import json
from pathlib import Path
import statistics
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("pid", type=int)
parser.add_argument("--seconds", type=int, default=30)
parser.add_argument("--label", default="idle")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / "local-metrics"
output.mkdir(exist_ok=True)
probe = output / "resource-probe"
subprocess.run(["xcrun", "clang", "-O2", str(root / "scripts/resource-probe.c"), "-o", str(probe)], check=True)

def read():
    return json.loads(subprocess.check_output([str(probe), str(args.pid)], text=True))

samples = [read()]
started = time.monotonic()
for _ in range(args.seconds):
    time.sleep(1)
    samples.append(read())
elapsed = time.monotonic() - started
first, last = samples[0], samples[-1]
result = {
    "mode": args.label,
    "elapsed_seconds": round(elapsed, 3),
    "cpu_seconds": round((last["cpu_ns"] - first["cpu_ns"]) / 1e9, 6),
    "cpu_percent_one_core": round((last["cpu_ns"] - first["cpu_ns"]) / 1e9 / elapsed * 100, 4),
    "median_physical_footprint_mb": round(statistics.median(s["footprint_bytes"] for s in samples) / 1e6, 3),
    "peak_physical_footprint_mb": round(max(s["footprint_bytes"] for s in samples) / 1e6, 3),
    "median_rss_mb": round(statistics.median(s["rss_bytes"] for s in samples) / 1e6, 3),
    "package_idle_wakeups": last["idle_wakeups"] - first["idle_wakeups"],
    "interrupt_wakeups": last["interrupt_wakeups"] - first["interrupt_wakeups"],
}
(output / (args.label + ".json")).write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
