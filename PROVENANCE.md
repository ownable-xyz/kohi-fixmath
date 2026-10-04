# Provenance

Source verification of the deployed `Trig256` published the Solidity sources in
this repository. The proof of reproducible bytecode (refer to
`docs/bytecode-identity.md`) is valid only while the code of the sources stays
identical. Thus, the sources are read-only.

| File | Upstream | License |
|---|---|---|
| `src/Fix64.sol` | Kohi, adapted from FixedMath.Net / libfixmath | MIT |
| `src/Trig256.sol` | Kohi | MIT |
| `src/Errors.sol` | Kohi | MIT |
| `src/SinLut256.sol` | generated; values are Kohi's MIT SinLut256 | MIT |

`src/SinLut256.sol` is a generated file. Its table values are Kohi's MIT
SinLut256, so it carries the author's copyright and keeps the Kohi MIT
notice. The full MIT text is in `LICENSE`.

## Rule

Do not edit these sources to change the behavior of the code. A change of
behavior is a new deployment. If you change the behavior, record every hash in
`docs/bytecode-identity.md` again.

A block explorer publishes the comments in these files. Thus, each comment must
be complete without other files:

- Do not use paths that are relative to the repository.
- Do not refer to files other than the file that contains the comment.

A change to comments only does not change a hash.
