"""Build and run the examples the way Cryft's own contract repos do: py-solc-x at the pinned compiler, on an in-memory
chain (eth-tester / py-evm). No Foundry, no Hardhat.

    python -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python -m pytest -q

The compiler is pinned in compiler.json (solc 0.8.37, optimizer 200 runs, EVM shanghai), the same settings Cryft's
builds use. py-solc-x installs it on first use (`python -m solcx.install v0.8.37`) if it isn't already there.
"""
import ast
import json
import re
from functools import lru_cache
from pathlib import Path

import pytest
import solcx
from eth_utils import keccak
from web3 import Web3
from web3.providers.eth_tester import EthereumTesterProvider

ROOT = Path(__file__).resolve().parent.parent
COMPILER = json.loads((ROOT / "compiler.json").read_text())
STUB_REMIX = (ROOT / "tests" / "remix_stub" / "remix_tests.sol").read_text()


def sources(*folders):
    """Every .sol under the folders, keyed by its path from ROOT (so relative imports resolve exactly as in Remix)."""
    out = {}
    for folder in folders:
        for path in sorted((ROOT / folder).rglob("*.sol")):
            out[path.relative_to(ROOT).as_posix()] = {"content": path.read_text()}
    return out


@lru_cache(maxsize=4)
def build(with_remix_tests=False):
    """Compile once per run. Returns {name: {abi, bytecode, runtime, layout, warnings}} and the compiler's messages."""
    solcx.set_solc_version(COMPILER["solc"])
    srcs = sources("contracts", "tests/support")
    if with_remix_tests:
        srcs.update(sources("remix-tests"))
        srcs["remix_tests.sol"] = {"content": STUB_REMIX}       # Remix provides this at run time; a stand-in here
    out = solcx.compile_standard({
        "language": "Solidity",
        "sources": srcs,
        "settings": {
            "optimizer": COMPILER["optimizer"],
            "evmVersion": COMPILER["evmVersion"],
            "outputSelection": {"*": {"*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object", "storageLayout"]}},
        },
    }, solc_version=COMPILER["solc"])
    errors = [e for e in out.get("errors", []) if e["severity"] == "error"]
    assert not errors, "\n".join(e["formattedMessage"] for e in errors)
    contracts = {}
    for file, items in out["contracts"].items():
        for name, c in items.items():
            contracts[name] = {"file": file, "abi": c["abi"], "bytecode": c["evm"]["bytecode"]["object"],
                               "runtime": c["evm"]["deployedBytecode"]["object"], "layout": c.get("storageLayout", {})}
    return contracts, out.get("errors", [])


@pytest.fixture(scope="session")
def built():
    return build()[0]


@pytest.fixture
def chain():
    """A fresh chain per test, with funded accounts."""
    provider = EthereumTesterProvider()
    w3 = Web3(provider)
    w3.eth.default_account = w3.eth.accounts[0]
    w3.tester = provider.ethereum_tester
    return w3


@pytest.fixture
def deploy(chain, built):
    def _deploy(name, *args, sender=None):
        c = built[name]
        factory = chain.eth.contract(abi=c["abi"], bytecode=c["bytecode"])
        tx = factory.constructor(*args).transact({"from": sender or chain.eth.accounts[0]})
        receipt = chain.eth.wait_for_transaction_receipt(tx)
        assert receipt.status == 1, f"{name} did not deploy"
        return chain.eth.contract(address=receipt.contractAddress, abi=c["abi"])
    return _deploy


@pytest.fixture
def at(chain, built):
    """The contract `name`'s ABI at `address` (for a proxy: the implementation's ABI at the proxy's address)."""
    return lambda name, address: chain.eth.contract(address=address, abi=built[name]["abi"])


def selector(signature):
    return "0x" + keccak(text=signature).hex()[:8]


def revert_data(exc):
    """The revert's raw data, as hex without 0x, from whichever form the provider raised it in."""
    data = getattr(exc, "data", None)
    if isinstance(data, (bytes, bytearray)):
        return bytes(data).hex()
    if isinstance(data, str) and data.startswith("0x"):
        return data[2:].lower()
    found = re.search(r"execution reverted: (b'(?:[^'\\]|\\.)*'|b\"(?:[^\"\\]|\\.)*\")", str(exc))
    return ast.literal_eval(found.group(1)).hex() if found else ""


@pytest.fixture
def reverts():
    """reverts(call, "TooEarly(uint64)") asserts the call reverts, with that custom error when one is named."""
    def _reverts(call, error=None):
        with pytest.raises(Exception) as caught:
            call()
        if error:
            assert revert_data(caught.value).startswith(selector(error)[2:]), f"expected {error}, got {caught.value!r}"
        return caught.value
    return _reverts


@pytest.fixture
def travel(chain):
    """Move the chain's clock forward by `seconds` and mine a block."""
    def _travel(seconds):
        now = chain.eth.get_block("latest")["timestamp"]
        chain.tester.time_travel(now + seconds)
        chain.tester.mine_blocks(1)
    return _travel
