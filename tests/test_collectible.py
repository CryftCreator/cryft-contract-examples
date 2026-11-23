"""04: ERC-1155 items, made the way Cryft's Giftables are, behind the example proxy."""
DAY = 86400


def items_world(chain, deploy, at):
    owner, minter = chain.eth.accounts[0], chain.eth.accounts[1]
    impl = deploy("CollectibleItems")
    timelock = deploy("ExampleTimelock", owner, DAY)
    proxy = deploy("ExampleProxy", impl.address, timelock.address, impl.encode_abi("initialize", args=[owner, minter]))
    return owner, minter, at("CollectibleItems", proxy.address)


def test_mint_one_of_one_with_kind_privacy_and_uri(chain, deploy, at):
    owner, minter, items = items_world(chain, deploy, at)
    alice = chain.eth.accounts[2]
    items.functions.mint(alice, "greeting", True, "ipfs://cover.json").transact({"from": minter})
    assert items.functions.balanceOf(alice, 1).call() == 1
    assert items.functions.itemOf(1).call() == ["greeting", True, "ipfs://cover.json"]
    assert items.functions.supportsInterface("0xd9b67a26").call()


def test_inputs_and_batches_are_bounded(chain, deploy, at, reverts):
    owner, minter, items = items_world(chain, deploy, at)
    alice = chain.eth.accounts[2]
    reverts(lambda: items.functions.mint(alice, "", False, "u").transact({"from": minter}), "InvalidItem()")
    reverts(lambda: items.functions.mint(alice, "k" * 33, False, "u").transact({"from": minter}), "InvalidItem()")
    reverts(lambda: items.functions.mint(alice, "k", False, "u" * 257).transact({"from": minter}), "InvalidItem()")
    reverts(lambda: items.functions.mintBatch([alice] * 101, "k", False, "u").transact({"from": minter}), "BatchTooLarge()")
    items.functions.mintBatch([alice] * 3, "postcard", False, "ipfs://p.json").transact({"from": minter})
    assert items.functions.totalSupply().call() == 3


def test_only_the_holder_moves_an_item_and_approvals_are_off(chain, deploy, at, reverts):
    owner, minter, items = items_world(chain, deploy, at)
    alice, bob = chain.eth.accounts[2:4]
    items.functions.mint(alice, "ticket", False, "ipfs://t.json").transact({"from": minter})
    reverts(lambda: items.functions.setApprovalForAll(bob, True).transact({"from": alice}), "ApprovalsDisabled()")
    reverts(lambda: items.functions.safeTransferFrom(alice, bob, 1, 1, b"").transact({"from": bob}), "NotAuthorized()")
    reverts(lambda: items.functions.safeTransferFrom(alice, bob, 2, 1, b"").transact({"from": alice}), "NoSuchItem()")
    reverts(lambda: items.functions.safeTransferFrom(alice, bob, 1, 2, b"").transact({"from": alice}), "Insufficient()")
    items.functions.safeTransferFrom(alice, bob, 1, 1, b"").transact({"from": alice})
    assert items.functions.balanceOf(bob, 1).call() == 1


def test_receivers_must_accept_and_minting_can_be_stopped(chain, deploy, at, reverts):
    owner, minter, items = items_world(chain, deploy, at)
    accepting, refusing = deploy("AcceptingReceiver"), deploy("RefusingReceiver")
    items.functions.mint(accepting.address, "greeting", False, "ipfs://g.json").transact({"from": minter})
    reverts(lambda: items.functions.mint(refusing.address, "greeting", False, "ipfs://g.json").transact({"from": minter}), "ReceiverRefused()")
    items.functions.setMinter("0x" + "00" * 20).transact({"from": owner})            # the exit path: no more minting
    reverts(lambda: items.functions.mint(owner, "k", False, "u").transact({"from": minter}), "NotMinter()")
