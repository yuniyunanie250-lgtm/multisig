# multisig

An m-of-n multisig in ~120 lines of Solidity: owners submit, confirm, and execute
transactions once the threshold is reached.

A multisig replaces "one private key holds the treasury" with "m of n keys must
agree". This is the minimal useful version, written to be readable rather than
feature-complete.

## Model

- `submit(target, value, data)` records a transaction and auto-confirms it for the
  proposer, returning a `txId`.
- `confirm(txId)` / `revoke(txId)` add or remove an owner's confirmation.
- `execute(txId)` runs the call once `confirmations >= threshold`. It is callable
  by anyone, which is normal: the value has already been authorised.
- `addOwner` / `removeOwner` manage the owner set; removal is blocked if it would
  leave fewer owners than the threshold.

One owner has at most one live confirmation per transaction, enforced by the
`confirmedBy` mapping rather than by convention.

## What it deliberately does not do

- **No off-chain signature collection.** Every confirmation is an on-chain
  transaction. Real deployments usually add EIP-712 signatures so approvals can be
  gathered for free and submitted in one go.
- **No reentrancy guard.** The transaction is marked executed before the external
  call, and there is no callback into the multisig's own state, but if you add
  features that re-enter, add a guard.
- **No daily limits, no guardian, no upgrade path.** Those are policy decisions
  and belong in the layer above this contract.

## Development

```bash
forge install foundry-rs/forge-std
forge test -vvv
```

## License

MIT
