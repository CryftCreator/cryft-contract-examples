"""The licence header every Solidity file carries, from provenance.json (one source of truth).

    python tools/provenance.py          # rewrite each file's header from the table
    python tools/provenance.py --check  # exit 1 if any file's header differs (the tests run this too)

A header is the SPDX line, then the file's own copyright, then where it is adapted from and any upstream portions.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER_MOST = 12                      # lines a header may take; bounds the strip below


def table() -> dict:
    return json.loads((ROOT / "provenance.json").read_text(encoding="utf-8"))


def short(commit: str) -> str:
    return commit[:12] if len(commit) == 40 else commit


def holder(copyright_line: str) -> str:
    return copyright_line.replace("Copyright (c) ", "© ")


def upstream_line(up: dict, adapted: bool) -> str:
    if "verified" in up:                                     # a deployed contract's public, verified source
        verb = "Adapted from" if adapted else "Portions derived from"
        return f"// {verb} {up['contract']} ({up['publisher']}), verified source at {up['verified']}, {up['license']}, {holder(up['copyright'])}."
    where = f"{up['repository']}/{up['path']} @ {short(up['commit'])}"
    if up["license"] == "CC0-1.0":
        return f"// Follows {up['repository']}/{up['path']}, CC0-1.0 (a standard; no copyright claimed)."
    if up.get("repository", "").startswith("OpenZeppelin/"):
        product = "OpenZeppelin Contracts Upgradeable" if "upgradeable" in up["repository"] else "OpenZeppelin Contracts"
        return f"// Portions derived from {product} {up['commit']} ({up['path']}), MIT, {holder(up['copyright'])}."
    verb = "Adapted from" if adapted else "Portions derived from"
    return f"// {verb} {where}, {up['license']}, {holder(up['copyright'])}."


def header(rel: str, t: dict) -> list[str]:
    f = t["files"][rel]
    lines = [f"// SPDX-License-Identifier: {f['license']}"]
    if f["adapted_from"]:
        lines.append("// Copyright (c) 2026 Cryft Labs (this adaptation).")
        lines.append(upstream_line(t["upstreams"][f["adapted_from"]], True))
    else:
        lines.append("// Copyright (c) 2026 Cryft Labs. Written for these examples.")
    lines += [upstream_line(t["upstreams"][p], False) for p in f["portions"]]
    if f.get("note"):
        lines.append(f"// {f['note']}")
    lines.append("// See NOTICE and provenance.json.")
    return lines


def strip(text: str) -> list[str]:
    """The file without its header: the leading // lines (SPDX, copyright, provenance), at most HEADER_MOST."""
    lines = text.split("\n")
    i = 0
    while i < len(lines) and i < HEADER_MOST and lines[i].startswith("//"):
        i += 1
    return lines[i:]


def render(rel: str, t: dict) -> str:
    return "\n".join(header(rel, t) + strip((ROOT / rel).read_text(encoding="utf-8")))


def main(argv: list[str]) -> int:
    t = table()
    stale = []
    for rel in sorted(t["files"]):
        want = render(rel, t)
        path = ROOT / rel
        if path.read_text(encoding="utf-8") != want:
            stale.append(rel)
            if "--check" not in argv:
                path.write_text(want, encoding="utf-8")
    if "--check" in argv and stale:
        print("headers out of date:", ", ".join(stale))
        return 1
    print(("checked " if "--check" in argv else "wrote ") + f"{len(t['files'])} headers")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
