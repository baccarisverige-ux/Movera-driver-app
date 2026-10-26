#!/usr/bin/env python3
"""Line coverage of one source folder from an lcov file, with a floor.

usage: tool/check_coverage.py coverage/lcov.info lib/core/ 91.5

Prints hit/lines and the percentage; exits 1 below the floor or when no
file under the folder is in the report.
"""
import sys


def main(argv):
    if len(argv) != 4:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    path, prefix, floor = argv[1], argv[2], float(argv[3])
    hit = lines = files = 0
    current = False
    with open(path, encoding="utf-8") as report:
        for raw in report:
            line = raw.strip()
            if line.startswith("SF:"):
                current = line[3:].startswith(prefix)
                files += current
            elif current and line.startswith("LF:"):
                lines += int(line[3:])
            elif current and line.startswith("LH:"):
                hit += int(line[3:])
    if not files or not lines:
        print(f"no coverage for {prefix} in {path}", file=sys.stderr)
        return 1
    pct = 100.0 * hit / lines
    print(f"{prefix}: {hit}/{lines} lines = {pct:.2f} % "
          f"({files} files; floor {floor:.2f} %)")
    if pct < floor:
        print(f"coverage of {prefix} fell below {floor:.2f} %", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
