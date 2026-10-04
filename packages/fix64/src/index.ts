// SPDX-License-Identifier: MIT
/*
 * @kohi/fix64: signed Q31.32 fixed-point math, the base of determinism for the
 * KVM. The package is separate so that @kohi/noise-lgpl (LGPL-2.1) can depend
 * on permissive math and not depend on the VM. This package is a port of the
 * Kohi Solidity libraries Fix64/Trig256/SinLut256, which are MIT (adapted from
 * FixedMath.Net / libfixmath). Refer to LICENSE.
 */
export * from "./fix64.js";
