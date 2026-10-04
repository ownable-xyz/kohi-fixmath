# Bytecode identity

The deployable contracts of this repository reproduce, byte for byte, the code
that is deployed on mainnet. This is the purpose of the repository. The bytecode
is identical only with the build settings in `foundry.toml`. If you change one
of these settings, the hash changes:

- solc 0.8.24
- evm cancun
- optimizer on / 200 runs
- via_ir off
- `bytecode_hash = "none"`
- `cbor_metadata = false`

## Recorded runtime hashes

Each hash is the `sha256` of the output of `forge inspect <c> deployedBytecode`
(hex, with the newline removed):

| Contract | sha256(deployedBytecode) | len (hex) | deployed |
|---|---|---|---|
| Trig256 | `9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d` | 6674 | yes |
| Fix64 | `7eb644109ff707b97453f309120396560bcbafccc7c788cdc6d8b62a97224bb4` | 734 | no (inlined) |
| SinLut256 | `ee83c880a1209c590795d81f5aad68659971c5916ad3b646efc66d8272e217cc` | 64 | no (inlined) |

Only `Trig256` is deployed. The other two are libraries with only `internal`
functions. The standalone artifact of each library is only the non-callable
guard stub. The table shows their hashes only to make the record complete.

## Reproduce

    forge build
    forge inspect src/Trig256.sol:Trig256 deployedBytecode | tr -d '\n' | sha256sum
    # => 9e4d0e8e8712c70230085669c170a45ff58f243b3ded1b0bf4fc9a0f3ec9645d

`npm run check:bytecode` compares the build with this hash. Thus, an accidental
edit of a source or a change of the settings makes the check fail.
