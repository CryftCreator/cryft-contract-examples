"""The Remix-format tests (remix-tests/*_test.sol) also compile with the pinned solc and pass here, run the way Remix runs
them: deploy, beforeAll(), then each check function; every AssertionEvent must pass."""
from eth_abi import decode
from eth_utils import keccak

from conftest import build

ASSERTION = "0x" + keccak(text="AssertionEvent(bool,string,string)").hex()
SKIP = {"beforeAll", "beforeEach", "onERC1155Received", "onERC1155BatchReceived"}


def test_remix_tests_compile_and_pass(chain):
    contracts, _ = build(with_remix_tests=True)
    suites = {n: c for n, c in contracts.items() if c["file"].startswith("remix-tests/") and c["bytecode"]}
    assert sorted(suites) == ["CardReadsTest", "CollectibleTest", "SponsoredGasTest", "UpgradeableTest"]
    for name, c in suites.items():
        factory = chain.eth.contract(abi=c["abi"], bytecode=c["bytecode"])
        suite = chain.eth.contract(address=chain.eth.wait_for_transaction_receipt(factory.constructor().transact()).contractAddress, abi=c["abi"])
        suite.functions.beforeAll().transact({"gas": 15_000_000})
        checks = [f["name"] for f in c["abi"] if f["type"] == "function" and f["name"] not in SKIP and f["stateMutability"] != "view"]
        assert checks, name
        for check in checks:
            receipt = chain.eth.wait_for_transaction_receipt(getattr(suite.functions, check)().transact({"gas": 10_000_000}))
            assert receipt.status == 1, f"{name}.{check} reverted"
            results = [decode(["bool", "string", "string"], bytes(log["data"])) for log in receipt.logs
                       if log["topics"] and "0x" + log["topics"][0].hex().removeprefix("0x") == ASSERTION]
            assert results, f"{name}.{check}: no assertions"
            failed = [message for passed, message, _ in results if not passed]
            assert not failed, f"{name}.{check}: {failed}"
