# 02 · Reading a Cryft card

`CardStatusReader` reads a card's public status from the live Cryft Cards and card authority contracts in one call:
minted, burned, written off, collectible, its state (opened or not), its maker, and its own account (where its gifts
live). `requireLiveOpenedCard(id)` lets your contract refuse anything but a live, opened card.

This is a starting point: review and test it for your own contract.

## Addresses

Read them from the card service, never hard-code them:

```
GET https://api.cryft.cards/v1/platform/tenants/cryft.cards/v8/config   → cards, authority (with a cards:read key)
```

Both are proxies, so their addresses stay the same across upgrades. Deploy `CardStatusReader(cards, authority)`.

## Who holds a card?

A card's NFT always sits in the card vault, so `ownerOf` answers the vault for every minted card. Who *holds* a card
is a credential the card authority checks by proof. To ask "which cards does this user hold", use the card service
with that user's session (docs: *List my cards*). This example reads only the public status.

## Safety

- Read-only: holds nothing, changes nothing, can't be paused or redirected (addresses are immutable and checked once).
- Never calls something that would revert when earlier reads already say the card isn't live (`metadataOf` returns "").
- An unknown state value is treated as "no card", never as opened.
- Batches are bounded (`BATCH_MOST` = 50).
