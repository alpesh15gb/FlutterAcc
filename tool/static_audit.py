#!/usr/bin/env python3
"""Source-level audit for environments without the Dart/Flutter SDK.

This is intentionally not a compiler replacement. It catches broken relative
imports, unbalanced delimiters/strings/comments, stale retired API routes, and
unfinished-work markers before the real `flutter analyze` release gate.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DART_ROOTS = [ROOT / "lib", ROOT / "test"]

STALE_ROUTES = {
    "/sales-returns": "/returns/sales",
    "/purchase-returns": "/returns/purchase",
    "/bill-payments": "/payments/disbursements",
}
MARKERS = re.compile(r"\b(TODO|FIXME|PLACEHOLDER|NOT IMPLEMENTED|COMING SOON)\b", re.I)
REL_IMPORT = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.M)


def dart_files() -> list[Path]:
    files: list[Path] = []
    for base in DART_ROOTS:
        if base.exists():
            files.extend(base.rglob("*.dart"))
    return sorted(files)


def relative_import_errors(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    for match in REL_IMPORT.finditer(text):
        value = match.group(1)
        if value.startswith(("dart:", "package:")):
            continue
        resolved = (path.parent / value).resolve()
        if not resolved.exists():
            errors.append(f"{path.relative_to(ROOT)}: missing import {value}")
    return errors


def syntax_shape_errors(path: Path, text: str) -> list[str]:
    """Lex just enough Dart to verify strings/comments and (), [], {} shape."""
    errors: list[str] = []
    stack: list[tuple[str, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    line = 1
    i = 0
    n = len(text)
    state = "code"
    quote = ""
    triple = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        tri = text[i : i + 3]
        if ch == "\n":
            line += 1

        if state == "line_comment":
            if ch == "\n":
                state = "code"
            i += 1
            continue
        if state == "block_comment":
            if ch == "*" and nxt == "/":
                state = "code"
                i += 2
            else:
                i += 1
            continue
        if state == "string":
            if ch == "\\":
                i += 2
                continue
            if triple:
                if tri == quote * 3:
                    state = "code"
                    i += 3
                else:
                    i += 1
            else:
                if ch == quote:
                    state = "code"
                i += 1
            continue

        # code
        if ch == "/" and nxt == "/":
            state = "line_comment"
            i += 2
            continue
        if ch == "/" and nxt == "*":
            state = "block_comment"
            i += 2
            continue
        if tri in ("'''", '\"\"\"'):
            quote = tri[0]
            triple = True
            state = "string"
            i += 3
            continue
        if ch in ("'", '"'):
            quote = ch
            triple = False
            state = "string"
            i += 1
            continue
        if ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                errors.append(
                    f"{path.relative_to(ROOT)}:{line}: unmatched closing {ch}"
                )
                return errors
            stack.pop()
        i += 1

    if state == "string":
        errors.append(f"{path.relative_to(ROOT)}:{line}: unterminated string")
    elif state == "block_comment":
        errors.append(f"{path.relative_to(ROOT)}:{line}: unterminated block comment")
    if stack:
        opening, opening_line = stack[-1]
        errors.append(
            f"{path.relative_to(ROOT)}:{opening_line}: unclosed delimiter {opening}"
        )
    return errors


def main() -> int:
    files = dart_files()
    errors: list[str] = []
    marker_hits: list[str] = []
    stale_hits: list[str] = []

    for path in files:
        text = path.read_text(encoding="utf-8")
        errors.extend(relative_import_errors(path, text))
        errors.extend(syntax_shape_errors(path, text))
        for line_no, line in enumerate(text.splitlines(), 1):
            if MARKERS.search(line):
                marker_hits.append(f"{path.relative_to(ROOT)}:{line_no}: {line.strip()}")
            for stale, replacement in STALE_ROUTES.items():
                if stale in line:
                    stale_hits.append(
                        f"{path.relative_to(ROOT)}:{line_no}: stale {stale}; use {replacement}"
                    )

    # Documentation is also expected to be free from unfinished markers and stale routes.
    for base in (ROOT / "docs", ROOT):
        candidates = list(base.glob("*.md")) if base.exists() else []
        for path in candidates:
            text = path.read_text(encoding="utf-8")
            for line_no, line in enumerate(text.splitlines(), 1):
                if MARKERS.search(line):
                    marker_hits.append(f"{path.relative_to(ROOT)}:{line_no}: {line.strip()}")

    all_errors = errors + stale_hits + marker_hits
    print(f"Dart source files checked: {len(files)}")
    print(f"Broken relative imports: {sum('missing import' in e for e in errors)}")
    print(f"Delimiter/string issues: {sum('missing import' not in e for e in errors)}")
    print(f"Stale API route literals: {len(stale_hits)}")
    print(f"Unfinished-work markers: {len(marker_hits)}")
    if all_errors:
        print("\nFAIL")
        for item in all_errors:
            print(f"- {item}")
        return 1
    print("\nPASS: source-level audit is clean.")
    print("Note: this does not replace `flutter analyze` or `flutter test`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
