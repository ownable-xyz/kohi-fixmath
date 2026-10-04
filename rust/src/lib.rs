// SPDX-License-Identifier: MIT
//! kohi-fixmath: permissive Q31.32 fixed-point math (Fix64 / Trig256 / SinLut256).
//! The Solidity, TypeScript and Rust implementations give identical values.
//!
//! The deployed Trig256 calculates with the same routines. The routines are
//! permissive and standalone. As a result, the LGPL noise can link permissive
//! math and does not depend on other code.

pub mod fix64;
pub mod sinlut;

pub use fix64::Fx;

#[cfg(test)]
mod smoke {
    use super::fix64::*;
    #[test]
    fn arithmetic_identities() {
        assert_eq!(mul(ONE, ONE), ONE);
        assert_eq!(add(ONE, ONE), TWO);
        assert_eq!(sub(TWO, ONE), ONE);
    }
}
