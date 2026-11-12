#!/usr/bin/env python3
"""Firebase Test Lab device run: scrub the downloaded results, then summarise.

Owner 2026-11-12 ("U need find problems! So whats the point of test"): the
staging device test (integration_test/staging_device_test.dart) prints one
line per check to logcat ("MOVERA-TL CHECK <id> PASS|FAIL|SKIP ...") and
writes summary.json into the app's files folder, which Test Lab pulls.

Usage (from .github/workflows/android-test-apk.yml, plain Python 3):
  TL_SCRUB="<value>\\n<value>" python3 tool/testlab_summary.py scrub DIR
      replace every listed value (phone number forms, sign-in code) with
      [REDACTED] in every text file under DIR, before anything is uploaded.
      Values come from the environment, never from the command line.
  python3 tool/testlab_summary.py summary DIR
      print passed/failed per check, JUnit totals and crash lines from
      logcat; also into $GITHUB_STEP_SUMMARY when set. Exit 0 (the Test Lab
      outcome decides the job).
"""
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

REDACTED = "[REDACTED]"
PREFIX = "MOVERA-TL "
CRASH_PATTERNS = [
    re.compile(p)
    for p in (
        r"FATAL EXCEPTION",
        r"AndroidRuntime",
        r"SecurityException",
        r"ANR in ",
        r"Unhandled Exception",
        r"EXCEPTION CAUGHT BY",
        r"ForegroundServiceStartNotAllowedException",
        r"\bE[ /]flutter\b",
        r"Process .* has died",
    )
]
MAX_CRASH_LINES = 40


def _is_text(data):
    return b"\0" not in data[:8192]


def scrub(root, secrets):
    """Replaces each secret in every text file under root; returns files changed."""
    values = sorted({s for s in secrets if len(s) >= 4}, key=len, reverse=True)
    changed = 0
    for path in glob.glob(os.path.join(root, "**", "*"), recursive=True):
        if not os.path.isfile(path):
            continue
        with open(path, "rb") as fh:
            data = fh.read()
        if not _is_text(data):
            continue
        text = data.decode("utf-8", errors="surrogateescape")
        new = text
        for value in values:
            new = new.replace(value, REDACTED)
        if new != text:
            with open(path, "wb") as fh:
                fh.write(new.encode("utf-8", errors="surrogateescape"))
            changed += 1
    return changed


def _logcat_files(root):
    out = []
    for path in glob.glob(os.path.join(root, "**", "*"), recursive=True):
        name = os.path.basename(path).lower()
        if os.path.isfile(path) and ("logcat" in name or name.endswith(".log")):
            out.append(path)
    return sorted(out)


def _lines(path):
    with open(path, "rb") as fh:
        return fh.read().decode("utf-8", errors="replace").splitlines()


def checks_from(root):
    """The check list: summary.json if pulled, else the logcat SUMMARY-JSON line."""
    for path in sorted(glob.glob(os.path.join(root, "**", "summary.json"), recursive=True)):
        try:
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data, list):
                return data, path
        except (OSError, ValueError):
            continue
    found = None
    checks = []
    for path in _logcat_files(root):
        for line in _lines(path):
            at = line.find(PREFIX + "SUMMARY-JSON ")
            if at >= 0:
                try:
                    found = json.loads(line[at + len(PREFIX + "SUMMARY-JSON "):])
                except ValueError:
                    pass
                continue
            at = line.find(PREFIX + "CHECK ")
            if at >= 0:
                parts = line[at + len(PREFIX + "CHECK "):].split(" ", 2)
                if len(parts) == 3:
                    checks.append({"id": parts[0], "outcome": parts[1].lower(),
                                   "title": "", "detail": parts[2]})
    if isinstance(found, list):
        return found, "logcat SUMMARY-JSON"
    if checks:
        return checks, "logcat CHECK lines"
    return [], None


def skipped_from(root):
    for path in _logcat_files(root):
        for line in _lines(path):
            at = line.find(PREFIX + "SKIP ")
            if at >= 0:
                return line[at + len(PREFIX):].strip()
    return None


def junit_from(root):
    totals = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    failed = []
    for path in glob.glob(os.path.join(root, "**", "*.xml"), recursive=True):
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue
        for case in tree.iter("testcase"):
            totals["tests"] += 1
            if case.find("failure") is not None:
                totals["failures"] += 1
                failed.append(case.get("name", "?"))
            elif case.find("error") is not None:
                totals["errors"] += 1
                failed.append(case.get("name", "?"))
            elif case.find("skipped") is not None:
                totals["skipped"] += 1
    return totals, failed


def crash_lines(root):
    seen = []
    for path in _logcat_files(root):
        for line in _lines(path):
            if PREFIX in line:
                continue
            if any(p.search(line) for p in CRASH_PATTERNS):
                short = line.strip()[:300]
                if short not in seen:
                    seen.append(short)
                if len(seen) >= MAX_CRASH_LINES:
                    return seen
    return seen


def summary_text(root):
    checks, source = checks_from(root)
    totals, failed_cases = junit_from(root)
    crashes = crash_lines(root)
    out = ["## Test Lab device checks (staging)", ""]
    skipped = skipped_from(root)
    if skipped:
        out += ["NOT CHECKED: " + skipped, ""]
    if checks:
        out.append("| Check | Result | Detail |")
        out.append("|---|---|---|")
        for c in checks:
            detail = str(c.get("detail", "")).replace("|", "/")[:400]
            title = c.get("title") or ""
            out.append("| %s %s | %s | %s |" % (c.get("id"), title, str(c.get("outcome", "")).upper(), detail))
        out += ["", "(from %s)" % source]
    elif not skipped:
        out.append("NOT CHECKED: no check results found (the test did not start or its output was not pulled).")
    out += ["", "JUnit: tests=%(tests)d failures=%(failures)d errors=%(errors)d skipped=%(skipped)d" % totals]
    if failed_cases:
        out.append("Failed JUnit cases: " + ", ".join(failed_cases))
    out += ["", "Crash / error lines in logcat: %d" % len(crashes)]
    if crashes:
        out.append("```")
        out += crashes
        out.append("```")
    return "\n".join(out) + "\n"


def main(argv):
    if len(argv) != 3 or argv[1] not in ("scrub", "summary"):
        print(__doc__)
        return 2
    root = argv[2]
    if argv[1] == "scrub":
        secrets = [s.strip() for s in os.environ.get("TL_SCRUB", "").splitlines()]
        changed = scrub(root, secrets)
        print("scrubbed %d file(s)" % changed)
        return 0
    text = summary_text(root)
    print(text)
    step = os.environ.get("GITHUB_STEP_SUMMARY")
    if step:
        with open(step, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
