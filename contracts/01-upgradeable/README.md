# 01 · Upgradeable, behind a proxy, with a timelock

`ExampleProxy` (ERC-1967) holds the state and keeps one address forever. `NoticeBoardV1` is the logic. `ExampleTimelock`
is the proxy's admin: an upgrade is scheduled in public, waits at least a day, then runs. `NoticeBoardV2` is the upgrade:
same address, same data, one new feature.

This is a starting point: review and test it for your own contract.

## Deploy

1. Deploy `NoticeBoardV1` (the implementation; its constructor locks it so nobody can initialize it).
2. Deploy `ExampleTimelock(owner, delay)`; `delay` is 1 to 30 days.
3. Deploy `ExampleProxy(implementation, timelock, initializeCalldata)`, where the calldata is `initialize(owner)`.
4. On the timelock, `adopt(proxy)`.
5. Use the contract at the **proxy's** address with V1's ABI.

## Upgrade

1. Deploy `NoticeBoardV2`.
2. `timelock.schedule(v2, initializeV2())`: announced at once (`UpgradeScheduled`).
3. After the delay, `timelock.execute()`. Or `cancel()` before then.

## Safety

- The implementation can't be taken over: `_disableInitializers()` runs in its constructor.
- Initialization is atomic: the proxy can't exist without it.
- Only the timelock upgrades, and only after its delay; the delay is immutable and bounded.
- Storage is append-only: V2 keeps every V1 slot (`tests/test_upgradeable.py` checks the layout).
- Ownership moves in two steps.
- Inputs are bounded (a notice is 1 to 280 bytes); no loops; no native coin held (plain transfers revert).
- Exit paths: cancel a scheduled upgrade; authors can remove their notice in V2. To give up upgrades for good, hand the
  timelock's ownership to a contract that can do nothing, or to a multisig.
