#!/usr/bin/env python3
"""Size budget for a Flutter web release build (audit Phase 7; step 50 / U4).

Usage:
  python3 tool/check_web_budget.py build/web --variant demo|live [--now YYYY-MM-DD]
  python3 tool/check_web_budget.py build/web --main-raw BYTES --main-gzip BYTES
  python3 tool/check_web_budget.py --self-test

Measures main.dart.js (the Dart program every visit downloads before the first
frame): its raw size and its gzip -9 size. The budgets live in
tool/web_budget.json, one entry per build variant:

* budget_raw / budget_gzip: the size measured on `measured_on` plus 2 %,
  rounded up to the next KiB (owner decision Q51, 2026-11-09). A breach prints
  a GitHub `::warning::` and exits 0 until `warn_until`; from that date on it
  prints `::error::` and exits 1.
* hard_raw / hard_gzip (optional): the older fixed CI limit. A breach always
  exits 1, warn window or not. The budget never exceeds the hard limit.

The old `--main-raw/--main-gzip` flags still work and behave as hard limits.
Raise a budget on purpose, in the same change that needs the bytes, and record
the new measurement in the JSON; never to make a red build green.
"""
import argparse
import datetime as _dt
import gzip
import json
import pathlib
import sys
import tempfile

BUDGET_FILE = pathlib.Path(__file__).with_name("web_budget.json")


def measure(build_dir: pathlib.Path):
    main_js = build_dir / "main.dart.js"
    if not main_js.is_file():
        raise FileNotFoundError(f"missing {main_js}")
    data = main_js.read_bytes()
    return len(data), len(gzip.compress(data, compresslevel=9))


def load_variant(budget_file: pathlib.Path, variant: str):
    config = json.loads(budget_file.read_text())
    try:
        entry = config["variants"][variant]
    except KeyError:
        raise SystemExit(f"unknown variant {variant!r}; known: {', '.join(config['variants'])}")
    warn_until = _dt.date.fromisoformat(entry.get("warn_until", config["warn_until"]))
    limits = {}
    for kind in ("raw", "gzip"):
        budget = entry[f"budget_{kind}"]
        hard = entry.get(f"hard_{kind}")
        if hard is not None and budget > hard:
            budget = hard  # never looser than the limit that passes today
        limits[kind] = (budget, hard)
    return limits, warn_until


def check(raw: int, packed: int, limits, warn_until, today: _dt.date, label: str) -> int:
    """Prints the verdict; returns the exit code (0 pass or warning, 1 fail)."""
    in_warn_window = today < warn_until
    (budget_raw, hard_raw), (budget_gzip, hard_gzip) = limits["raw"], limits["gzip"]
    print(
        f"{label}: {raw:,} bytes (budget {budget_raw:,}"
        + (f", hard {hard_raw:,}" if hard_raw else "")
        + f"), gzip -9 {packed:,} bytes (budget {budget_gzip:,}"
        + (f", hard {hard_gzip:,}" if hard_gzip else "")
        + f"); warn-until {warn_until.isoformat()}, today {today.isoformat()}"
    )
    failed = False
    for kind, size, budget, hard in (("raw", raw, budget_raw, hard_raw), ("gzip", packed, budget_gzip, hard_gzip)):
        if hard is not None and size > hard:
            print(f"::error::{label} is {size - hard:,} bytes over its hard {kind} limit of {hard:,}", file=sys.stderr)
            failed = True
        elif size > budget:
            over = size - budget
            if in_warn_window:
                print(
                    f"::warning::{label} is {over:,} bytes over its {kind} budget of {budget:,}; "
                    f"this blocks from {warn_until.isoformat()}",
                    file=sys.stderr,
                )
            else:
                print(f"::error::{label} is {over:,} bytes over its {kind} budget of {budget:,}", file=sys.stderr)
                failed = True
        else:
            print(f"{kind}: {budget - size:,} bytes of budget left")
    return 1 if failed else 0


def self_test() -> int:
    warn_until = _dt.date(2026, 11, 17)
    limits = {"raw": (1000, 2000), "gzip": (500, 1500)}
    cases = [
        ("under budget", 900, 400, _dt.date(2026, 11, 10), 0),
        ("over budget before warn-until -> warning", 1100, 400, _dt.date(2026, 11, 10), 0),
        ("over budget after warn-until -> failure", 1100, 400, _dt.date(2026, 11, 20), 1),
        ("over budget on warn-until day -> failure", 1100, 400, _dt.date(2026, 11, 17), 1),
        ("over hard limit in warn window -> failure", 2100, 400, _dt.date(2026, 11, 10), 1),
    ]
    ok = True
    for name, raw, packed, today, expected in cases:
        print(f"-- self-test: {name}")
        got = check(raw, packed, limits, warn_until, today, "fake main.dart.js")
        verdict = "ok" if got == expected else f"FAILED (exit {got}, expected {expected})"
        ok &= got == expected
        print(f"   {verdict}")
    # A real file through the whole path, against the shipped JSON.
    with tempfile.TemporaryDirectory() as tmp:
        build = pathlib.Path(tmp)
        (build / "main.dart.js").write_bytes(b"x" * 10)
        raw, packed = measure(build)
        limits, until = load_variant(BUDGET_FILE, "demo")
        got = check(raw, packed, limits, until, _dt.date(2026, 11, 20), "tiny main.dart.js")
        ok &= got == 0 and raw == 10
        print("   ok" if got == 0 else "   FAILED")
    for variant in ("demo", "live"):
        lim, _ = load_variant(BUDGET_FILE, variant)
        for kind, (budget, hard) in lim.items():
            if hard is not None and budget > hard:
                ok = False
                print(f"   FAILED: {variant} {kind} budget above hard limit")
    print("self-test " + ("OK" if ok else "FAILED"))
    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("build_dir", nargs="?")
    parser.add_argument("--variant", choices=("demo", "live"), help="budget entry in tool/web_budget.json")
    parser.add_argument("--budget-file", type=pathlib.Path, default=BUDGET_FILE)
    parser.add_argument("--main-raw", type=int, help="hard raw limit (legacy flag)")
    parser.add_argument("--main-gzip", type=int, help="hard gzip limit (legacy flag)")
    parser.add_argument("--now", type=_dt.date.fromisoformat, default=_dt.date.today(), help="pretend today is YYYY-MM-DD")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.build_dir:
        parser.error("build_dir is required")
    try:
        raw, packed = measure(pathlib.Path(args.build_dir))
    except FileNotFoundError as err:
        print(err, file=sys.stderr)
        return 1
    if args.variant:
        limits, warn_until = load_variant(args.budget_file, args.variant)
        if args.main_raw is not None or args.main_gzip is not None:
            parser.error("--variant and --main-raw/--main-gzip are exclusive")
    elif args.main_raw is not None and args.main_gzip is not None:
        limits = {"raw": (args.main_raw, args.main_raw), "gzip": (args.main_gzip, args.main_gzip)}
        warn_until = args.now
    else:
        parser.error("give --variant, or both --main-raw and --main-gzip")
    return check(raw, packed, limits, warn_until, args.now, f"main.dart.js ({args.variant or 'legacy limits'})")


if __name__ == "__main__":
    sys.exit(main())
