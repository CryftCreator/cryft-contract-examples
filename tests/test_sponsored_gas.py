"""03: a contract made to be sponsored, and a per-wallet daily policy for a developer's gas account."""
from eth_utils import keccak

OP = lambda n: keccak(text=f"op-{n}")
MILLI = 10 ** 15


def policy_world(chain, deploy, per_op=2 * MILLI, daily=4 * MILLI):
    sponsor = deploy("FakeGasSponsor")
    owner, account = chain.eth.accounts[0], chain.eth.accounts[9]
    policy = deploy("WalletDailyPolicy", sponsor.address, account, owner, per_op, daily)
    hook = lambda fn, *args: sponsor.functions.call(policy.address, policy.encode_abi(fn, args=list(args))).transact()
    return sponsor, policy, hook


def test_guestbook_bounds_its_inputs_and_rate(chain, deploy, reverts, travel):
    book = deploy("SponsoredGuestbook")
    alice = chain.eth.accounts[1]
    reverts(lambda: book.functions.sign("").transact({"from": alice}), "InvalidMessage()")
    reverts(lambda: book.functions.sign("x" * 201).transact({"from": alice}), "InvalidMessage()")
    book.functions.sign("hello").transact({"from": alice})
    reverts(lambda: book.functions.sign("again").transact({"from": alice}), "TooSoon(uint256)")
    travel(61)
    book.functions.sign("again").transact({"from": alice})
    assert book.functions.entries().call() == 2


def test_limits_are_validated(chain, deploy, reverts):
    sponsor, policy, _ = policy_world(chain, deploy)
    reverts(lambda: policy.functions.setDefaultLimit(True, 0, MILLI).transact(), "InvalidConfiguration()")
    reverts(lambda: policy.functions.setDefaultLimit(True, 2 * MILLI, MILLI).transact(), "InvalidConfiguration()")
    reverts(lambda: policy.functions.setDefaultLimit(False, MILLI, MILLI).transact(), "InvalidConfiguration()")
    reverts(lambda: policy.functions.setDefaultLimit(True, MILLI, MILLI).transact({"from": chain.eth.accounts[1]}), "Unauthorized()")


def test_only_the_sponsor_reserves_and_each_operation_is_used_once(chain, deploy, reverts):
    sponsor, policy, hook = policy_world(chain, deploy)
    alice = chain.eth.accounts[1]
    reverts(lambda: policy.functions.reserve(OP(1), alice, MILLI).transact(), "Unauthorized()")
    hook("reserve", OP(1), alice, MILLI)
    reverts(lambda: hook("reserve", OP(1), alice, MILLI), "OperationAlreadyUsed()")
    hook("settle", OP(1), MILLI // 2)
    reverts(lambda: hook("reserve", OP(1), alice, MILLI), "OperationAlreadyUsed()")
    reverts(lambda: hook("settle", OP(1), 1), "InvalidSettlement()")


def test_per_operation_and_daily_limits_hold_across_pending_reservations(chain, deploy, reverts, travel):
    sponsor, policy, hook = policy_world(chain, deploy)
    alice = chain.eth.accounts[1]
    reverts(lambda: hook("reserve", OP(1), alice, 3 * MILLI), "AllowanceUnavailable()")   # over per-operation
    hook("reserve", OP(1), alice, 2 * MILLI)
    hook("reserve", OP(2), alice, 2 * MILLI)                                              # the day's 4 reserved
    reverts(lambda: hook("reserve", OP(3), alice, 1), "AllowanceUnavailable()")
    reverts(lambda: hook("settle", OP(1), 2 * MILLI + 1), "InvalidSettlement()")         # never more than reserved
    hook("settle", OP(1), MILLI)
    hook("settle", OP(2), MILLI)
    assert policy.functions.allowance(alice).call()[3] == 2 * MILLI
    travel(86400)
    assert policy.functions.allowance(alice).call()[3] == 4 * MILLI                       # a new day


def test_exit_paths_pause_and_disable_a_wallet(chain, deploy, reverts):
    sponsor, policy, hook = policy_world(chain, deploy)
    alice, bob = chain.eth.accounts[1:3]
    policy.functions.setWalletLimit(bob, True, False, 0, 0).transact()
    reverts(lambda: hook("reserve", OP(1), bob, MILLI), "AllowanceUnavailable()")
    policy.functions.setPaused(True).transact()
    reverts(lambda: hook("reserve", OP(2), alice, MILLI), "AllowanceUnavailable()")
    assert policy.functions.allowance(alice).call()[0] is False
