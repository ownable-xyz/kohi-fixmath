# @kohi/fix64

**License: MIT.** This package contains signed Q31.32 fixed-point math:

- `Fix64` (add/sub/mul/div, `log_256`/`exp`)
- `Trig256` (`sin`/`cos`)
- the generated `SinLut256` table

This package is the **base of determinism for the KVM**. Each backend
(TypeScript, Solidity, Rust/wasm) must give byte-identical results. As a
result, a minted piece renders the same on each backend.

## Why this is a separate package

The package is separate so that `@kohi/noise-lgpl` (LGPL-2.1) can depend on it
and not depend on the VM. Thus a third party can build that library again from
permissive parts. This package contains those parts.

## The MIT license comes from the upstream sources

This package is a bit-for-bit port of the Kohi Art Community Solidity libraries
`Fix64`, `Trig256` and `SinLut256`. Those libraries are adaptations of
**FixedMath.Net** and **libfixmath**. All of these have the MIT license. The
port has the same license. This package contains only standard fixed-point
arithmetic. It does not contain the parts that give the VM its value (the ISA,
the rasterizers, the container format, the catalog).

## Do not change the results

Each function must stay byte-identical to the Solidity libraries. Do not change
the rounding. Do not simplify the code. A difference breaks the determinism
between backends. `sinlut.ts` is a **generated** file that comes from the
`SinLut256` table. Do not edit it manually.
