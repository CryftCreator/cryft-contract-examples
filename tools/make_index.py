"""Write index.json: every example with its files and each file's sha256, for the code editor's shared-contracts library
(code.cryft.cards fetches a pinned release tag, checks each file against this list, and refuses any mismatch).

    .venv/bin/python tools/make_index.py            # rewrite index.json
    .venv/bin/python tools/make_index.py --check    # exit 1 if index.json is out of date (tests/test_index.py runs this)

The version comes from VERSION below; the release tag is "v" + VERSION. Bump it, regenerate, commit, then tag the public repo.
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "1.0.2"
REPOSITORY = "https://github.com/CryftCreator/cryft-contract-examples"
FILES_MOST = 200
FILE_BYTES_MOST = 256 * 1024

SHARED = ["README.md", "LICENSE", "LICENSE-APACHE", "LICENSE-MIT", "NOTICE", "provenance.json", "compiler.json", "requirements.txt", ".gitignore",
          "tests/conftest.py", "tests/test_build.py", "tests/test_remix_tests.py", "tests/remix_stub/remix_tests.sol",
          "tools/standard_input.py", "tools/make_index.py", "tools/provenance.py", "tests/test_index.py",
          "tests/test_provenance.py"]
EXAMPLES = [
    {"id": "01-upgradeable", "title": "Upgradeable, behind a proxy, with a timelock",
     "summary": "An ERC-1967 proxy whose address never changes, a timelock admin, and a V1 → V2 upgrade that keeps the data.",
     "files": ["contracts/01-upgradeable/*", "remix-tests/upgradeable_test.sol", "tests/test_upgradeable.py"]},
    {"id": "02-card-reads", "title": "Reading a Cryft card",
     "summary": "A Cryft card's public status in one call, and gating your own contract on a live, opened card.",
     "files": ["contracts/02-card-reads/*", "remix-tests/card_reads_test.sol", "tests/support/MockCards.sol", "tests/test_card_reads.py"]},
    {"id": "03-sponsored-gas", "title": "Built for developer gas sponsorship",
     "summary": "A contract written to be called through sponsorship, and a per-wallet daily policy for your gas account.",
     "files": ["contracts/03-sponsored-gas/*", "remix-tests/sponsored_gas_test.sol", "tests/support/Receivers.sol", "tests/test_sponsored_gas.py"]},
    {"id": "04-collectible-1155", "title": "ERC-1155 items for cards",
     "summary": "One-of-one items with a kind, a privacy flag and their own metadata, no approvals, behind the example proxy.",
     "files": ["contracts/04-collectible-1155/*", "contracts/01-upgradeable/Initializable.sol", "contracts/01-upgradeable/ExampleProxy.sol",
               "contracts/01-upgradeable/ExampleTimelock.sol", "remix-tests/collectible_test.sol", "tests/support/Receivers.sol",
               "tests/test_collectible.py"]},
]


def entry(rel):
    data = (ROOT / rel).read_bytes()
    if len(data) > FILE_BYTES_MOST:
        raise SystemExit(f"{rel} is over {FILE_BYTES_MOST} bytes")
    return {"path": rel, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}


def expand(patterns):
    out = []
    for pattern in patterns:
        if pattern.endswith("/*"):
            out += sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / pattern[:-2]).iterdir() if p.is_file())
        else:
            out.append(pattern)
    return out


def build():
    examples = [{**{k: e[k] for k in ("id", "title", "summary")}, "files": [entry(p) for p in expand(e["files"])]} for e in EXAMPLES]
    index = {"schema": 1, "name": "cryft-contract-examples", "version": VERSION, "tag": f"v{VERSION}", "repository": REPOSITORY,
             "compiler": json.loads((ROOT / "compiler.json").read_text()), "shared": [entry(p) for p in SHARED], "examples": examples}
    count = len({f["path"] for f in index["shared"]} | {f["path"] for e in examples for f in e["files"]})
    if count > FILES_MOST:
        raise SystemExit(f"more than {FILES_MOST} files")
    return json.dumps(index, indent=2, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    text = build()
    if "--check" in sys.argv:
        current = (ROOT / "index.json").read_text() if (ROOT / "index.json").exists() else ""
        sys.exit(0 if current == text else "index.json is out of date: run tools/make_index.py")
    (ROOT / "index.json").write_text(text)
    print(f"index.json: v{VERSION}")
