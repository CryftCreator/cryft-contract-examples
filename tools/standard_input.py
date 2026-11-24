"""Write the standard-JSON input for one example contract, with exactly the pinned settings, for "Verify & publish" on
explore.cryft.cards (Solidity, Standard JSON input, compiler v0.8.37).

    .venv/bin/python tools/standard_input.py contracts/01-upgradeable/NoticeBoardV1.sol
    → build/NoticeBoardV1.standard-input.json

Only the file and what it imports go in, so nothing else in your folder is published.
"""
import json
import posixpath
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPILER = json.loads((ROOT / "compiler.json").read_text())
IMPORT = re.compile(r'^\s*import\s+(?:[^"\']*from\s+)?["\']([^"\']+)["\']', re.M)
FILES_MOST = 64                                     # a bounded walk: an example never imports more than this


def closure(entry):
    seen, todo = {}, [entry]
    while todo:
        if len(seen) >= FILES_MOST:
            raise SystemExit(f"more than {FILES_MOST} files: stop")
        rel = todo.pop()
        if rel in seen:
            continue
        path = (ROOT / rel).resolve()
        if ROOT not in path.parents:
            raise SystemExit(f"{rel} is outside the examples")
        text = path.read_text()
        seen[rel] = text
        for found in IMPORT.findall(text):
            # resolved as solc resolves a relative import: against the importing file's folder, "../" collapsed
            todo.append(posixpath.normpath(posixpath.join(posixpath.dirname(rel), found)) if found.startswith(".") else found)
    return {k: {"content": v} for k, v in sorted(seen.items())}


def standard_input(entry):
    return {"language": "Solidity", "sources": closure(entry), "settings": {
        "optimizer": COMPILER["optimizer"], "evmVersion": COMPILER["evmVersion"],
        "outputSelection": {"*": {"*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object", "metadata"]}}}}


def main(argv):
    if len(argv) != 2 or not argv[1].endswith(".sol"):
        raise SystemExit(__doc__)
    entry = posixpath.normpath(Path(argv[1]).as_posix())
    data = standard_input(entry)
    out = ROOT / "build" / (Path(entry).stem + ".standard-input.json")
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(data, indent=2))
    print(f"{out.relative_to(ROOT)}  (solc {COMPILER['solc']}, {COMPILER['evmVersion']}, {COMPILER['optimizer']['runs']} runs)")


if __name__ == "__main__":
    main(sys.argv)
