# 04 · ERC-1155 items for cards

`CollectibleItems` makes items your app can put inside Cryft Cards, the way Cryft's own Giftables (greeting cards,
postcards, …) are made: every item is its own token id, one of one, with a `kind`, a `privateContents` flag and its own
metadata URI. Mint an item straight into a card's account (`CardStatusReader.accountOf`, example 02), and it travels
with the card.

It is upgradeable: deploy it behind `ExampleProxy` with an `ExampleTimelock` as admin (example 01).

This is a starting point: review and test it for your own contract.

## Deploy

1. `CollectibleItems()` (the implementation; locked).
2. `ExampleTimelock(owner, delay)`.
3. `ExampleProxy(implementation, timelock, initialize(owner, minter))`, then `timelock.adopt(proxy)`.

## Safety

- No approvals: only an item's holder moves it, so no operator can outlive a change of holder.
- Bounded: at most `MAX_BATCH` (100) per batch; `kind` up to 32 bytes, `uri` up to 256.
- Only existing items move; balances use checked arithmetic.
- A receiving contract must accept (ERC-1155 receiver check); one refusal reverts the whole batch.
- Exit paths: the owner can change the minter or stop minting for good (`setMinter(address(0))`); holders can always
  move their own items.
- Privacy: `privateContents` only marks the URI as a neutral cover. Never put private words on chain; keep them
  encrypted off chain for the holder.
