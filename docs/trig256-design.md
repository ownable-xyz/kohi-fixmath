# Trig256 design notes

These notes describe the implementation of `src/Trig256.sol`. They help a person
who changes the file. They do not belong in the public comments of the contract.

## `E` is a negative sentinel, not the value e

`exp()` has a fast path: `if (x == Fix64.ONE) return E;`. The constant is:

    int64 private constant E = -0x2B7E15162;

`0x2B7E15162` is `11674931554`. That number divided by `2^32` is
`2.718281828...`, which is Euler's number in Q31.32. But the constant has a
**negative** sign. Thus, `Trig256.exp(Fix64.ONE)` returns `-2.718281828...`,
not `e`.

Do not change the sign in this repository. The sign looks like an error, but the
library reproduces an upstream implementation bit for bit, and the sign comes
from that implementation. The upstream implementation is derived from
FixedMath.NET. `test/golden/fixmath.json` records `exp(1<<32) == -11674931554`
as a golden vector (`test/Fixmath.t.sol: test_Trig256_exp`). A change of the
sign changes the deployed bytecode and makes that test fail. The purpose of
`src/Trig256.sol` is to reproduce the deployed `Trig256` bytecode with no
differences.

If a caller needs the mathematically correct e^1, do not add a special case for
this constant. Use one of these methods:

- Use the general power series path. That path applies to each x that has a
  small difference from `Fix64.ONE`.
- Use `log`/`log2` in the opposite direction.

## sqrt()'s two-pass structure

`Trig256.sqrt(int64 x)` uses the digit-by-digit binary square root algorithm. It
runs the algorithm two times on the 64-bit word, one time for each 32-bit half.
A renormalization step (the `if (i == 0) { ... }` block) occurs between the two
passes. As a result, the output already has the Q31.32 scale. A single-pass
integer sqrt of a Q31.32 value has a scale of `2^16`, not `2^32`, and needs a
separate rescale. Measurements confirm the scale: `sqrt(ONE) == ONE`,
`sqrt(4*ONE) == 2*ONE`, `sqrt(ONE/4) == ONE/2`.

## Why the cold public functions have staticcall stubs (`_ext1`)

`log`, `exp`, `acos`, `log_256` and `atan2` are `public`. Thus, `Trig256` is
deployable and callers can use the ABI to call it.

`extLog`, `extExp`, `extAcos`, `extLog256` and `extAtan2` are handwritten
wrappers. Each wrapper makes a staticcall to the deployed address of the
library. The library uses these wrappers internally. Without them, solc
generates an ABI-encoded delegatecall stub at each call site of an external
library function, and each stub has a cost.

The callees are `pure` and always return one 32-byte word on success. Thus, the
wrapper does not check the length of the return data. This is an optimization of
gas and size. It has no effect on correctness. If the function selectors change,
change the wrappers to agree.
