#!/usr/bin/env python3
"""Checks docs/store/metadata.md against App Store Connect's field limits (T-051).

Limits: App Store Connect Help, as summarized in research/app-store-release.md §6.1 ([10], [36]).
Exits non-zero if any field is missing or over its limit.
"""
import pathlib
import re
import sys

LIMITS = {
    # field: (unit, min, max)
    "name": ("chars", 2, 30),
    "subtitle": ("chars", 0, 30),
    "promo": ("chars", 0, 170),
    "description": ("chars", 1, 4000),
    "keywords": ("bytes", 1, 100),
    "review": ("bytes", 0, 4000),
}
URL_FIELDS = ["support", "privacy"]

text = (pathlib.Path(__file__).parent / "metadata.md").read_text(encoding="utf-8")
fields = {m.group(1): m.group(2) for m in re.finditer(r"```(\w+)\n(.*?)\n```", text, re.S)}

failures = 0
for field, (unit, low, high) in LIMITS.items():
    value = fields.get(field)
    if value is None:
        print(f"MISSING  {field}")
        failures += 1
        continue
    size = len(value.encode("utf-8")) if unit == "bytes" else len(value)
    ok = low <= size <= high
    failures += not ok
    print(f"{'OK  ' if ok else 'FAIL'}     {field:<12} {size:>5} {unit} (limit {low}–{high})")

keywords = fields.get("keywords", "").split(",")
short = [k for k in keywords if len(k.strip()) <= 2]
dupes = {k for k in keywords if keywords.count(k) > 1}
if short or dupes or any(k != k.strip() for k in keywords):
    print(f"FAIL     keywords: too short {short}, duplicates {sorted(dupes)}, or stray spaces")
    failures += 1
else:
    print(f"OK       keywords     {len(keywords)} terms, each > 2 characters, no duplicates")

for field in URL_FIELDS:
    value = fields.get(field, "")
    ok = value.startswith("https://")
    failures += not ok
    print(f"{'OK  ' if ok else 'FAIL'}     {field:<12} includes the protocol")

copyright_ok = re.fullmatch(r"\d{4} .+", fields.get("copyright", "")) is not None
failures += not copyright_ok
print(f"{'OK  ' if copyright_ok else 'FAIL'}     copyright    \"Year Owner\"")

sys.exit(1 if failures else 0)
