# 03 · Built for developer gas sponsorship

> **Sponsorship: Soon.** Paying for your users' calls from your gas account (`POST /developer/gas/execute` and the
> GasSponsor's allowed targets) isn't open on the card service yet. Both contracts deploy and work today; calls are
> paid by whoever sends them until sponsorship opens.

- `SponsoredGuestbook`: a target contract written to be called through sponsorship. List it as an allowed target so
  your gas account pays for calls to it and nothing else.
- `WalletDailyPolicy`: your own rules for your gas account, in code: a most per operation and a most per day, by
  default and per wallet. Attach it with `setSponsorPolicy`; the GasSponsor calls `reserve` before paying and `settle`
  after.

This is a starting point: review and test it for your own contract.

## Deploy

1. `SponsoredGuestbook()`.
2. `WalletDailyPolicy(gasSponsor, yourGasAccount, owner, perOperationWei, dailyWei)`: the GasSponsor is `0x…FEeD`
   on the Cryft Network; your gas account's id is on the dashboard's Gas page.

## Safety

- Identity is `msg.sender` (the user's own EIP-7702 account), never `tx.origin`, which is the relayer when sponsored.
- Inputs are bounded and each wallet waits between entries, so nobody can drain your gas account by flooding it.
- Only the GasSponsor may reserve or settle; each operation id is used once; a settlement never charges more than was
  reserved; pending reservations count against the day, so concurrent calls can't overspend.
- Limits are validated when set. Amounts are wei (integers).
- Exit paths: pause at once, disable one wallet, or detach the policy.
- No loops, no native coin held, no external calls in the policy.
