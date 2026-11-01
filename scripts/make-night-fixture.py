"""Build a Night test fixture from hr-tracker history CSVs.

Usage: python scripts/make-night-fixture.py <history.csv> [more.csv ...] <fixture.csv>

Reads the CSVs hr-tracker's tools/history.py writes from a .pklg capture, merges them by Record
Counter (a later file wins, as hr-tracker's sleep.py and metrics.py do) and writes one History
Record per line, oldest first, with only the fields the Night methods read:

    counter,utc,hr,rr_ms,q0,q1,q2,q3,temp_c,spo2_window,spo2

The values are hr-tracker's own, unchanged, so its sleep.py and metrics.py on the same CSVs give
the expected values the tests commit as literals. These columns hold no serial, device ID or
Bluetooth address (docs/conventions.md, Testing); the script fails if the input has any other
column, so nothing else can slip in. The .pklg and the sysdiagnose are never committed.
"""

import csv
import sys

COLUMNS = ["counter", "utc", "hr", "rr_ms", "q0", "q1", "q2", "q3", "temp_c", "spo2_window", "spo2"]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    *sources, out = sys.argv[1:]
    records = {}
    for path in sources:
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            if reader.fieldnames != COLUMNS:
                sys.exit(f"{path}: expected columns {COLUMNS}, got {reader.fieldnames}")
            for row in reader:
                counter = int(row["counter"])
                # The Strap can reuse a Record Counter after a reboot (GLOSSARY); merging by
                # counter alone would then silently drop a record, so refuse instead.
                if counter in records and records[counter]["utc"] != row["utc"]:
                    sys.exit(f"{path}: Record Counter {counter} reused at {row['utc']}")
                records[counter] = row
    with open(out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        for counter in sorted(records):
            writer.writerow(records[counter])
    print(f"{len(records)} History Records -> {out}")


if __name__ == "__main__":
    main()
