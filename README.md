# kohi-fixmath

This repository contains fixed-point math with a permissive license (MIT). You
can deploy it as a separate unit. The other parts of the Kohi stack link to this
math and do not inline it:

- The LGPL-2.1 value noise (`kohi-noise-lgpl`) depends only on this repository.
- The KVM uses the same deployed `Trig256`.

The math is permissive and is available separately. Thus a third party can
build the LGPL noise again from permissive parts.

All values are Q31.32 (`int64`, 32 fractional bits). The Solidity, TypeScript
and Rust implementations give identical values.

## Deployed contracts

Each link opens the contract on Etherscan.

| Contract | Mainnet | Sepolia |
|---|---|---|
| `Trig256` | [`0x9905c8152a46FDdD62e935CF496DBff3B65124d8`](https://etherscan.io/address/0x9905c8152a46FDdD62e935CF496DBff3B65124d8#code) | [`0xAF8f886Df2285a4Ca847AAA1a3223d420d79e886`](https://sepolia.etherscan.io/address/0xAF8f886Df2285a4Ca847AAA1a3223d420d79e886#code) |

## The deployed bytecode

Only `Trig256` deploys as its own contract. It has `public` log and exp
functions, and callers use `staticcall` to call them. `Fix64`, `SinLut256` and
`Errors` have only `internal` functions. The compiler inlines them into their
callers, so they are not deployed as separate contracts.

The `Trig256` runtime bytecode (the EIP-170 runtime, with the metadata removed)
has this hash:

    sha256(deployedBytecode) = 9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d

To calculate the hash again, run this command:

    forge inspect src/Trig256.sol:Trig256 deployedBytecode | tr -d '\n' | sha256sum

This is the bytecode that is deployed on mainnet. Refer to
`docs/bytecode-identity.md`.

## Build, test, deploy

    forge install                               # fetches lib/forge-std (test-only)
    forge build
    forge test
    node deploy/kohi-deploy.mjs status         # dry-run by default
    SEND=1 node deploy/kohi-deploy.mjs deploy   # broadcasts (gated)

## What is here

| File | Role | Deployed? |
|---|---|---|
| `src/Fix64.sol` | Q31.32 core arithmetic | no (inlined) |
| `src/Trig256.sol` | log / exp / log2 / trig over Fix64 | yes |
| `src/SinLut256.sol` | 256-entry Q31.32 sine LUT | no (inlined) |
| `src/Errors.sol` | shared custom errors | no |

## Provenance and license

Source verification of the deployed `Trig256` published these Solidity sources.
The reproducible bytecode needs these conditions:

- a pinned solc version
- no metadata in the bytecode
- LF line endings
- source code that stays identical

Refer to `PROVENANCE.md`.

All four sources have the MIT license. The full license text is in `LICENSE`.
