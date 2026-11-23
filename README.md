# Cryft platform contract examples

Four small contracts for developers building on the Cryft Network (Dakota), written the way Cryft writes its own:
every input bounded, every loop bounded, checks-effects-interactions, pull over push, and a way out of every state.

> **These are starting points, not audited products.** Read them, change them to fit your app, test them, and have
> them reviewed before they hold real value. You are responsible for the code you deploy.

| Example | What it shows | Adapted from |
|---|---|---|
| [01-upgradeable](contracts/01-upgradeable) | An upgradeable contract behind an ERC-1967 proxy, with a timelock as admin: upgrades keep the address | Cryft's vault proxy and its timelock |
| [02-card-reads](contracts/02-card-reads) | Reading a Cryft card's public status (minted, opened, its account) and gating your own code on it | Cryft Cards V8.2 and its card authority (verified on the explorer) |
| [03-sponsored-gas](contracts/03-sponsored-gas) | A contract made to be called through developer gas sponsorship, and a per-wallet daily policy for your gas account | The network's TenantAllowancePolicy template |
| [04-collectible-1155](contracts/04-collectible-1155) | ERC-1155 items to put inside cards (one of one, a kind, a privacy flag, no approvals) | Cryft's Giftables |

## Compiler

Pinned in [`compiler.json`](compiler.json): **solc 0.8.37**, optimizer on, **200 runs**, EVM **shanghai**: the settings
Cryft's own builds use. Use exactly these in Remix (Solidity compiler → 0.8.37, Advanced: optimization 200, EVM
shanghai) so what you deploy matches what you tested and what you verify.

## Size

The Cryft Network allows contracts up to **32 KB** (32,768 bytes) of deployed code. **Base keeps the usual 24 KB**
(24,576 bytes), so keep a contract under 24 KB if it must also deploy there. Every example here is far under both;
`tests/test_build.py` checks it.

| Contract | Deployed size |
|---|---|
| CollectibleItems | ~7.2 KB |
| WalletDailyPolicy | ~3.9 KB |
| CardStatusReader | ~3.4 KB |
| ExampleTimelock | ~3.1 KB |
| NoticeBoardV2 | ~2.7 KB |
| NoticeBoardV1 | ~2.2 KB |
| ExampleProxy | ~0.9 KB |
| SponsoredGuestbook | ~0.8 KB |

## Test

Like Cryft's own repos: pytest + py-solc-x on an in-memory chain (no Foundry, no Hardhat).

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m pytest -q
```

- `tests/test_*.py`: each example's behaviour, its bounds and its failure paths, plus the build checks (pinned
  compiler, sizes, no `tx.origin`, no unbounded loops).
- `remix-tests/*_test.sol`: the same ideas as Remix "Solidity Unit Testing" files. They also run here
  (`tests/test_remix_tests.py`) with a stand-in for Remix's `remix_tests.sol`.

## Deploy to the Cryft Network

| | |
|---|---|
| Network | Cryft Network (Dakota) |
| Chain id | `112311` |
| RPC | `https://rpc.dakota.cards` |
| Explorer | `https://explore.dakota.cards` |

Deploy with **your own wallet** (an injected browser wallet, or your own key on your own machine). Cryft's dashboard
never holds your keys. In Remix: Deploy & run → Environment "Injected Provider", with your wallet on chain 112311.

## Verify on the explorer

1. Write the exact input: `.venv/bin/python tools/standard_input.py contracts/<example>/<Contract>.sol` → `build/<Contract>.standard-input.json`.
2. Open your contract's address on `https://explore.dakota.cards`, choose **Verify & publish**, then **Solidity (Standard JSON input)**.
3. Pick compiler **v0.8.37**, upload the file, give the contract name and your constructor arguments (ABI-encoded), and submit.
4. For a proxy, verify the implementation too; the explorer links a proxy to its implementation.

`tests/test_build.py` checks that this input rebuilds exactly the code the tests ran.

## The rules every example follows

- **Bound every input**: type, range, length and count (`MESSAGE_MOST`, `MAX_BATCH`, `NOTICE_MOST`, …).
- **Bound every loop**: no loop over a list a user can grow; batches have a most.
- **Checks, effects, then interactions**: state is updated before any external call.
- **Pull over push**: nothing sends coins out in a loop; holders move their own items.
- **An exit path from every state**: cancel, pause, disable, stop minting, take your own entry down.
- **Least power**: two-step ownership, a timelock in front of upgrades, no approvals that outlive a holder.
- **Integers only for amounts** (wei); never floats, never rounding you didn't choose.
- **Identity is `msg.sender`**, never `tx.origin` (sponsored calls come through a relayer).

More in the docs: [Build safely](https://docs.cryft.cards/#build-safely).

## The shared-contracts library

`index.json` lists every example, its files, and each file's sha256. The code editor (code.cryft.cards) fetches a pinned
release tag of this repo, checks every file against this list before saving it, and refuses any mismatch. Regenerate it with
`.venv/bin/python tools/make_index.py` after any change (`tests/test_index.py` fails while it is out of date), bump `VERSION`
for a release, and tag `v<VERSION>`.

## Licence

Apache-2.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)).
