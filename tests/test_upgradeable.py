"""01: an upgradeable contract behind an ERC-1967 proxy, administered by a timelock. The address never changes."""
DAY = 86400


def setup(chain, deploy, at, delay=DAY):
    owner = chain.eth.accounts[0]
    impl = deploy("NoticeBoardV1")
    timelock = deploy("ExampleTimelock", owner, delay)
    init = impl.encode_abi("initialize", args=[owner])
    proxy = deploy("ExampleProxy", impl.address, timelock.address, init)
    timelock.functions.adopt(proxy.address).transact()
    return owner, impl, timelock, proxy, at("NoticeBoardV1", proxy.address)


def test_set_up_once_and_the_implementation_cannot_be_taken_over(chain, deploy, at, reverts):
    owner, impl, timelock, proxy, board = setup(chain, deploy, at)
    assert board.functions.owner().call() == owner
    assert board.functions.initializedVersion().call() == 1
    reverts(lambda: board.functions.initialize(chain.eth.accounts[1]).transact(), "AlreadyInitialized()")
    reverts(lambda: impl.functions.initialize(chain.eth.accounts[1]).transact(), "AlreadyInitialized()")
    assert impl.functions.initializedVersion().call() == 2 ** 64 - 1
    assert proxy.functions.proxyAdmin().call() == timelock.address
    assert proxy.functions.implementation().call() == impl.address


def test_inputs_are_bounded(chain, deploy, at, reverts):
    *_, board = setup(chain, deploy, at)
    reverts(lambda: board.functions.post("").transact(), "InvalidNotice()")
    reverts(lambda: board.functions.post("x" * 281).transact(), "InvalidNotice()")
    board.functions.post("x" * 280).transact()
    assert board.functions.notices().call() == 1


def test_an_upgrade_is_announced_waits_and_keeps_the_address_and_data(chain, deploy, at, reverts, travel):
    owner, impl, timelock, proxy, board = setup(chain, deploy, at)
    alice = chain.eth.accounts[1]
    board.functions.post("hello").transact({"from": alice})
    v2 = deploy("NoticeBoardV2")
    reverts(lambda: timelock.functions.schedule(v2.address, b"").transact({"from": alice}), "NotTheOwner()")
    data = v2.encode_abi("initializeV2", args=[])
    timelock.functions.schedule(v2.address, data).transact()
    reverts(lambda: timelock.functions.execute().transact(), "TooEarly(uint64)")
    reverts(lambda: timelock.functions.schedule(v2.address, data).transact(), "AlreadyScheduled()")
    travel(DAY + 1)
    timelock.functions.execute().transact()
    upgraded = at("NoticeBoardV2", proxy.address)
    assert proxy.functions.implementation().call() == v2.address
    assert upgraded.functions.version().call() == "notice-board-2"
    assert upgraded.functions.noticeOf(alice).call() == "hello"            # same address, same data
    assert upgraded.functions.initializedVersion().call() == 2
    reverts(lambda: upgraded.functions.initializeV2().transact(), "AlreadyInitialized()")
    upgraded.functions.remove().transact({"from": alice})                    # the new exit path
    assert upgraded.functions.notices().call() == 0


def test_only_the_admin_upgrades_and_a_schedule_can_be_cancelled(chain, deploy, at, reverts):
    owner, impl, timelock, proxy, board = setup(chain, deploy, at)
    v2 = deploy("NoticeBoardV2")
    reverts(lambda: proxy.functions.upgradeToAndCall(v2.address, b"").transact(), "NotTheAdmin()")
    timelock.functions.schedule(v2.address, b"").transact()
    timelock.functions.cancel().transact()
    reverts(lambda: timelock.functions.execute().transact(), "NothingScheduled()")


def test_the_delay_is_bounded_and_ownership_moves_in_two_steps(chain, deploy, reverts):
    owner, other = chain.eth.accounts[:2]
    reverts(lambda: deploy("ExampleTimelock", owner, 3600))
    reverts(lambda: deploy("ExampleTimelock", owner, 31 * 86400))
    timelock = deploy("ExampleTimelock", owner, 86400)
    timelock.functions.transferOwnership(other).transact()
    assert timelock.functions.owner().call() == owner                       # not until accepted
    timelock.functions.acceptOwnership().transact({"from": other})
    assert timelock.functions.owner().call() == other


def test_storage_is_append_only_from_v1_to_v2(built):
    v1 = [(s["label"], s["slot"], s["offset"]) for s in built["NoticeBoardV1"]["layout"]["storage"]]
    v2 = [(s["label"], s["slot"], s["offset"]) for s in built["NoticeBoardV2"]["layout"]["storage"]]
    assert v2[: len(v1)] == v1, "V2 must keep every V1 variable at the same slot"
    assert [label for label, *_ in v2[len(v1):]] == ["hidden"]


def test_plain_transfers_to_the_proxy_revert(chain, deploy, at, reverts):
    *_, proxy, board = setup(chain, deploy, at)
    reverts(lambda: chain.eth.send_transaction({"to": proxy.address, "value": 1}))
