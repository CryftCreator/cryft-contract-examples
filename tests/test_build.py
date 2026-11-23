"""Every example builds with the pinned compiler, within Dakota's 32 KB (and Base's 24 KB), and follows the rules."""
import re

import solcx

from conftest import COMPILER, ROOT, build

EXAMPLES = ["01-upgradeable", "02-card-reads", "03-sponsored-gas", "04-collectible-1155"]
DEPLOYABLE = ["ExampleProxy", "ExampleTimelock", "NoticeBoardV1", "NoticeBoardV2", "CardStatusReader",
              "WalletDailyPolicy", "SponsoredGuestbook", "CollectibleItems"]
# The one warning we keep on purpose: ExampleProxy has a payable fallback (so a payable implementation function can be
# called through it) but no receive(), so plain transfers revert instead of being stranded.
EXPECTED_WARNINGS = [re.compile(r"payable fallback function, but no receive ether function", re.S)]


def test_pinned_compiler():
    build()
    assert COMPILER == {"solc": "0.8.37", "evmVersion": "shanghai", "optimizer": {"enabled": True, "runs": 200},
                        "dakotaCodeSizeMost": 32768, "baseCodeSizeMost": 24576}
    assert str(solcx.get_solc_version(with_commit_hash=False)) == "0.8.37"


def test_no_unexpected_warnings():
    _, messages = build()
    for m in messages:
        if "/examples/" in m.get("sourceLocation", {}).get("file", "") or m["severity"] != "warning":
            continue
        assert any(w.search(m["formattedMessage"]) for w in EXPECTED_WARNINGS), m["formattedMessage"]


def test_sizes_fit_dakota_and_base(built):
    for name in DEPLOYABLE:
        size = len(built[name]["runtime"]) // 2
        assert 0 < size <= COMPILER["dakotaCodeSizeMost"], f"{name}: {size} bytes is over Dakota's 32 KB"
        assert size <= COMPILER["baseCodeSizeMost"], f"{name}: {size} bytes would not deploy on Base (24 KB)"


def test_each_example_has_a_readme_and_safety_notes():
    for example in EXAMPLES:
        readme = (ROOT / "contracts" / example / "README.md").read_text()
        assert "## Safety" in readme and "starting point" in readme.lower(), example
    for sol in (ROOT / "contracts").rglob("*.sol"):
        text = sol.read_text()
        assert text.startswith("// SPDX-License-Identifier: Apache-2.0\npragma solidity >=0.8.20 <0.9.0;"), sol.name
        assert "tx.origin" not in re.sub(r"//.*", "", text), f"{sol.name}: identity is msg.sender, never tx.origin"
        assert not re.search(r"\bselfdestruct\b|while\s*\(\s*true\s*\)|for\s*\(\s*;\s*;", text), f"{sol.name}: no unbounded loops"
        assert "PRIVATE DESIGN" not in text, f"{sol.name}: nothing from private designs"


def test_the_verification_input_rebuilds_the_same_code(built):
    """tools/standard_input.py: what you upload to the explorer compiles to exactly what the tests ran."""
    import sys
    sys.path.insert(0, str(ROOT / "tools"))
    from standard_input import standard_input
    for entry, name in [("contracts/04-collectible-1155/CollectibleItems.sol", "CollectibleItems"),
                        ("contracts/01-upgradeable/NoticeBoardV2.sol", "NoticeBoardV2")]:
        data = standard_input(entry)
        assert all(".." not in key for key in data["sources"]), "keys resolved as solc resolves them"
        out = solcx.compile_standard(data, solc_version=COMPILER["solc"])
        assert out["contracts"][entry][name]["evm"]["deployedBytecode"]["object"][:-106] == built[name]["runtime"][:-106] \
            or out["contracts"][entry][name]["evm"]["deployedBytecode"]["object"] == built[name]["runtime"]
