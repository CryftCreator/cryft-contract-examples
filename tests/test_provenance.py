"""Licensing follows the originals: every Solidity file's SPDX line and header match provenance.json, every Solidity file is
in the table, NOTICE lists every original and upstream with its copyright, and LICENSE names each licence's files."""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = json.loads((ROOT / "provenance.json").read_text(encoding="utf-8"))
SPDX = re.compile(r"^// SPDX-License-Identifier: ([A-Za-z0-9.\-]+)$")
LICENCES = {"MIT", "Apache-2.0"}


def solidity_files():
    return sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob("*.sol")
                  if not any(part.startswith(".") or part in ("node_modules", "build", "out") for part in p.relative_to(ROOT).parts))


def test_every_solidity_file_is_in_the_table_and_nothing_else():
    assert solidity_files() == sorted(TABLE["files"])


def test_spdx_matches_the_table_and_the_original():
    for rel, f in TABLE["files"].items():
        first = (ROOT / rel).read_text(encoding="utf-8").split("\n", 1)[0]
        m = SPDX.match(first)
        assert m, f"{rel}: the first line is its SPDX licence"
        assert m.group(1) == f["license"], rel
        assert f["license"] in LICENCES, rel
        if f["adapted_from"]:
            assert f["license"] == TABLE["upstreams"][f["adapted_from"]]["license"], f"{rel}: the original's licence"


def test_headers_name_the_original_and_each_upstream():
    for rel, f in TABLE["files"].items():
        head = "\n".join((ROOT / rel).read_text(encoding="utf-8").split("\n")[:10])
        assert "Copyright (c) 2026 Cryft Labs" in head, rel
        if f["adapted_from"]:
            u = TABLE["upstreams"][f["adapted_from"]]
            cited = (f"Adapted from {u['contract']} ({u['publisher']}), verified source at {u['verified']}, {u['license']}" if "verified" in u
                     else f"Adapted from {u['repository']}/{u['path']} @ {u['commit'][:12]}, {u['license']}")
            assert cited in head, rel
        for p in f["portions"]:
            u = TABLE["upstreams"][p]
            assert u.get("path", u.get("verified")) in head and u["license"] in head, f"{rel}: {p}"
            if u.get("repository", "").startswith("OpenZeppelin/"):
                assert "zOS Global Limited and contributors" in head, rel
    # the headers are exactly what tools/provenance.py writes from the table
    run = subprocess.run([sys.executable, str(ROOT / "tools/provenance.py"), "--check"], capture_output=True, text=True, timeout=60)
    assert run.returncode == 0, run.stdout + run.stderr


def test_upstreams_are_pinned_and_every_one_is_used():
    used = {f["adapted_from"] for f in TABLE["files"].values()} | {p for f in TABLE["files"].values() for p in f["portions"]}
    assert used - {None} == set(TABLE["upstreams"])
    for key, u in TABLE["upstreams"].items():
        if "verified" in u:                          # a deployed contract's verified source on the public explorer
            assert re.fullmatch(r"https://explore\.cryft\.cards/address/0x[0-9a-fA-F]{40}", u["verified"]), key
            assert u["contract"] and u["publisher"] == "Cryft Labs", key
        else:                                        # a public repository at a pinned commit or tag
            assert re.fullmatch(r"[0-9a-f]{40}|v\d+\.\d+\.\d+|final", u["commit"]), key
        assert u["license"] in LICENCES | {"CC0-1.0"}, key
        assert u["copyright"], key


def test_notice_lists_each_original_and_upstream_with_its_copyright():
    notice = (ROOT / "NOTICE").read_text(encoding="utf-8")
    for key, u in TABLE["upstreams"].items():
        assert (f"{u['contract']} ({u['publisher']}), verified source at {u['verified']}" if "verified" in u
                else f"{u['repository']} {u['path']}") in notice, key
        if u["license"] != "CC0-1.0":
            assert u["copyright"].replace("Modifications ", "") in notice, key
            if len(u.get("commit", "")) == 40:
                assert u["commit"] in notice, key
    assert "Copyright (c) 2016-2023 zOS Global Limited and contributors" in notice
    assert "Permission is hereby granted, free of charge" in notice, "OpenZeppelin's MIT licence text"


def test_nothing_names_a_private_source():
    """Originals in private repositories are cited only by their public, verified contracts."""
    for path in ROOT.rglob("*"):
        rel = path.relative_to(ROOT)
        if path.is_file() and not any(part.startswith(".") or part in ("node_modules", "__pycache__") for part in rel.parts) and path.suffix in (".sol", ".md", ".json", ".py", "") :
            text = path.read_text(encoding="utf-8", errors="ignore")
            for word in ("dakota-private-" + "design", "PRIVATE " + "DESIGN"):   # spelt apart so this file passes its own scan
                assert word not in text, str(rel)


def test_license_files_name_each_licences_files():
    top = (ROOT / "LICENSE").read_text(encoding="utf-8")
    for rel, f in TABLE["files"].items():
        if f["license"] == "MIT":
            assert rel in top, rel
    assert "Apache License" in (ROOT / "LICENSE-APACHE").read_text(encoding="utf-8")
    assert "Permission is hereby granted" in (ROOT / "LICENSE-MIT").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for key, u in TABLE["upstreams"].items():                 # public repositories link to the exact file at the exact commit
        if u.get("repository") == "cryft-labs/dakota-network":
            assert f"(https://github.com/{u['repository']}/blob/{u['commit']}/{u['path']})" in readme, key
    for rel, f in TABLE["files"].items():
        assert f"| `{rel}` | {f['license']} |" in readme, rel
