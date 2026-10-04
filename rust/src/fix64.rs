// SPDX-License-Identifier: MIT
//! Fix64: signed Q31.32 fixed-point math. MIT (Kohi's Fix64.sol / Trig256.sol).
//!
//! This is integer math with no allocation and no dependencies. Thus, it can
//! build as a wasm side module that shares one linear memory with a host
//! module. Each routine is value-identical to the Solidity library.
//!
//! Each line has an effect on determinism. Keep the
//! `cfg!(target_arch = "wasm32")` branches in `mul`/`mul256`/`div`, because a
//! wasm build and a native build must give the same bits. Do not change the
//! rounding and do not simplify the code.

use crate::sinlut::SINLUT256;

pub type Fx = i64;

pub const ONE: i64 = 4_294_967_296; // 1 << 32
pub const TWO: i64 = ONE * 2;
pub const PI: i64 = 0x3243f6a88;
pub const TWO_PI: i64 = 0x6487ed511;
pub const PI_OVER_2: i64 = 0x1921fb544;
pub const MAX_VALUE: i64 = i64::MAX;
pub const MIN_VALUE: i64 = i64::MIN;

const LARGE_PI: i64 = 7244019458077122842;

/// Addition with saturation (Fix64.add).
pub fn add(x: Fx, y: Fx) -> Fx {
    let sum = x.wrapping_add(y);
    if (!(x ^ y) & (x ^ sum) & MIN_VALUE) != 0 {
        return if x > 0 { MAX_VALUE } else { MIN_VALUE };
    }
    sum
}

/// Subtraction with saturation (Fix64.sub).
pub fn sub(x: Fx, y: Fx) -> Fx {
    let diff = x.wrapping_sub(y);
    if ((x ^ y) & (x ^ diff) & MIN_VALUE) != 0 {
        return if x < 0 { MIN_VALUE } else { MAX_VALUE };
    }
    diff
}

/// Multiplication that wraps and truncates (Fix64.mul): `i64((x * y) >> 32)`.
#[inline]
pub const fn mul(x: Fx, y: Fx) -> Fx {
    if cfg!(target_arch = "wasm32") {
        mul_limbs(x, y)
    } else {
        mul_i128(x, y)
    }
}

pub(crate) const fn mul_i128(x: Fx, y: Fx) -> Fx {
    (((x as i128) * (y as i128)) >> 32) as i64
}

pub(crate) const fn mul_limbs(x: Fx, y: Fx) -> Fx {
    let xlo = x as u64 & 0xffff_ffff;
    let xhi = x >> 32;
    let ylo = y as u64 & 0xffff_ffff;
    let yhi = y >> 32;
    let lolo = xlo.wrapping_mul(ylo);
    let lohi = (xlo as i64).wrapping_mul(yhi);
    let hilo = xhi.wrapping_mul(ylo as i64);
    let hihi = xhi.wrapping_mul(yhi);
    ((lolo >> 32) as i64)
        .wrapping_add(lohi)
        .wrapping_add(hilo)
        .wrapping_add(hihi.wrapping_shl(32))
}

/// The 256-bit variant (`mul256`). The index calculation of Trig256.sin uses it.
#[inline]
pub const fn mul256(x: i128, y: i128) -> i128 {
    const LIM: i128 = 1 << 47;
    if cfg!(target_arch = "wasm32") && x > -LIM && x < LIM && y > -LIM && y < LIM {
        mul256_small(x, y)
    } else {
        mul256_i128(x, y)
    }
}

pub(crate) const fn mul256_i128(x: i128, y: i128) -> i128 {
    let xlo = x & 0xffff_ffff;
    let xhi = x >> 32;
    let ylo = y & 0xffff_ffff;
    let yhi = y >> 32;

    let lolo = xlo * ylo; // The value is not negative.
    let lohi = xlo * yhi;
    let hilo = xhi * ylo;
    let hihi = xhi * yhi;

    let lo_result = lolo >> 32;
    let hi_result = hihi << 32;

    lo_result + lohi + hilo + hi_result
}

/// The same limb decomposition with 64-bit arithmetic. It is exact for |x|, |y| < 2^47.
pub(crate) const fn mul256_small(x: i128, y: i128) -> i128 {
    let xlo = (x as u64) & 0xffff_ffff;
    let xhi = (x >> 32) as i64;
    let ylo = (y as u64) & 0xffff_ffff;
    let yhi = (y >> 32) as i64;

    let lolo = xlo * ylo;
    let lohi = (xlo as i64) * yhi;
    let hilo = xhi * (ylo as i64);
    let hihi = xhi * yhi;

    (((lolo >> 32) as i64) + lohi + hilo + (hihi << 32)) as i128
}

/// Long division with rounding and saturation (Fix64.div). Panics if y == 0.
#[inline]
pub const fn div(x: Fx, y: Fx) -> Fx {
    if cfg!(target_arch = "wasm32") {
        div_longdiv(x, y)
    } else {
        div_i128(x, y)
    }
}

pub(crate) const fn div_i128(x: Fx, y: Fx) -> Fx {
    if y == 0 {
        panic!("Fix64: division by zero");
    }
    let ax = if x >= 0 { x as i128 } else { -(x as i128) };
    let ay = if y >= 0 { y as i128 } else { -(y as i128) };
    let q = (ax << 33) / ay;
    if q > 0xffff_ffff_ffff_ffff_i128 {
        return if ((x ^ y) & MIN_VALUE) == 0 { MAX_VALUE } else { MIN_VALUE };
    }
    let mut result = ((q + 1) >> 1) as i64; // This wraps as asIntN(64) does.
    if ((x ^ y) & MIN_VALUE) != 0 {
        result = result.wrapping_neg();
    }
    result
}

pub(crate) const fn div_longdiv(x: Fx, y: Fx) -> Fx {
    if y == 0 {
        panic!("Fix64: division by zero");
    }
    let ax = if x >= 0 { x as u64 } else { (x as u64).wrapping_neg() };
    let ay = if y >= 0 { y as u64 } else { (y as u64).wrapping_neg() };
    let hi = ax >> 31;
    let lo = ax << 33;
    if hi >= ay {
        return if ((x ^ y) & MIN_VALUE) == 0 { MAX_VALUE } else { MIN_VALUE };
    }
    let q = udiv128_64(hi, lo, ay);
    let mut result = ((q >> 1).wrapping_add(q & 1)) as i64;
    if ((x ^ y) & MIN_VALUE) != 0 {
        result = result.wrapping_neg();
    }
    result
}

/// floor((hi·2^64 + lo) / d) for hi < d (divlu from Hacker's Delight). The result is exact.
pub(crate) const fn udiv128_64(hi: u64, lo: u64, d: u64) -> u64 {
    const B: u64 = 1 << 32;
    let s = d.leading_zeros();
    let d = d << s;
    let (dh, dl) = (d >> 32, d & (B - 1));
    let un64 = if s == 0 { hi } else { (hi << s) | (lo >> (64 - s)) };
    let un10 = lo << s;
    let (un1, un0) = (un10 >> 32, un10 & (B - 1));

    let mut q1 = un64 / dh;
    let mut rhat = un64 - q1 * dh;
    while q1 >= B || q1 * dl > B * rhat + un1 {
        q1 -= 1;
        rhat += dh;
        if rhat >= B {
            break;
        }
    }
    let un21 = un64
        .wrapping_mul(B)
        .wrapping_add(un1)
        .wrapping_sub(q1.wrapping_mul(d));
    let mut q0 = un21 / dh;
    rhat = un21 - q0 * dh;
    while q0 >= B || q0 * dl > B * rhat + un0 {
        q0 -= 1;
        rhat += dh;
        if rhat >= B {
            break;
        }
    }
    q1 * B + q0
}

/// Fix64.floor for a wide value: `i64(x & ~0xffffffff)`.
pub const fn floor(x: i128) -> i64 {
    (x & !0xffff_ffff_i128) as i64
}

/// Banker's rounding for a wide value (Fix64.round). Returns the wide result
/// without a wrap, the same as the TS. Callers apply the i64 wrap when they use
/// the result.
pub const fn round256(x: i128) -> i128 {
    let fractional_part = x & 0x0000_0000_ffff_ffff;
    let integral_part = floor(x) as i128;
    if fractional_part < 0x8000_0000 {
        return integral_part;
    }
    if fractional_part > 0x8000_0000 {
        return integral_part + ONE as i128;
    }
    if (integral_part & ONE as i128) == 0 {
        return integral_part;
    }
    integral_part + ONE as i128
}

pub fn sign(x: Fx) -> i64 {
    if x == 0 {
        0
    } else if x > 0 {
        1
    } else {
        -1
    }
}

pub fn abs(x: Fx) -> Fx {
    // i64((x + mask) ^ mask). abs(MIN) wraps to MIN, the same as the TS.
    let mask = (x >> 63) as i128;
    (((x as i128) + mask) ^ mask) as i64
}

// ---------------------------------------------------------------------------
// Trig256 (sin / cos)
// ---------------------------------------------------------------------------

pub struct ClampedAngle {
    pub clamped: Fx,
    pub flip_horizontal: bool,
    pub flip_vertical: bool,
}

/// Reduces the argument to [0, PI/2) and gives the quadrant flip flags
/// (Trig256.clamp).
pub fn clamp_angle(x: Fx) -> ClampedAngle {
    let mut clamped_2pi = x;
    let mut i = 0;
    while i < 29 {
        if clamped_2pi > -(LARGE_PI >> 28) && clamped_2pi < (LARGE_PI >> 28) {
            break;
        }
        clamped_2pi %= LARGE_PI >> i;
        i += 1;
    }
    if x < 0 {
        clamped_2pi += TWO_PI;
    }

    let flip_vertical = clamped_2pi >= PI;
    let mut clamped_pi = clamped_2pi;
    while clamped_pi >= PI {
        clamped_pi -= PI;
    }

    let flip_horizontal = clamped_pi >= PI_OVER_2;

    let mut clamped_pi_over_2 = clamped_pi;
    if clamped_pi_over_2 >= PI_OVER_2 {
        clamped_pi_over_2 -= PI_OVER_2;
    }

    ClampedAngle { clamped: clamped_pi_over_2, flip_horizontal, flip_vertical }
}

/// The out-of-range behavior of the binary search tree of SinLut256: a negative
/// index reads entry 1, and an index above 255 reads entry 255.
fn sinlut(i: i64) -> Fx {
    if i < 0 {
        return SINLUT256[1];
    }
    if i > 255 {
        return SINLUT256[255];
    }
    SINLUT256[i as usize]
}

/// (256 - 1) * ONE / (PI/2). This is the scale of the LUT index.
const LUT_INTERVAL: i64 = div(255 * ONE, PI_OVER_2);

#[inline(never)]
pub fn sin(x: Fx) -> Fx {
    let ClampedAngle { clamped, flip_horizontal, flip_vertical } = clamp_angle(x);

    let raw_index = mul256(clamped as i128, LUT_INTERVAL as i128);
    let mut rounded_index = round256(raw_index) as i64; // This is the asIntN(64) wrap.
    let index_error = sub(raw_index as i64, rounded_index);

    rounded_index >>= 32;

    let nearest_value_index = if flip_horizontal { 255 - rounded_index } else { rounded_index };
    let nearest_value = sinlut(nearest_value_index);

    let second_nearest_value = sinlut(if flip_horizontal {
        255 - rounded_index - sign(index_error)
    } else {
        rounded_index + sign(index_error)
    });

    let delta = mul(index_error, abs(sub(nearest_value, second_nearest_value)));
    let interpolated_value =
        nearest_value.wrapping_add(if flip_horizontal { delta.wrapping_neg() } else { delta });
    if flip_vertical {
        interpolated_value.wrapping_neg()
    } else {
        interpolated_value
    }
}

pub fn cos(x: Fx) -> Fx {
    let angle = if x > 0 { add(x, sub(0i64.wrapping_sub(PI), PI_OVER_2)) } else { add(x, PI_OVER_2) };
    sin(angle)
}

// ---------------------------------------------------------------------------
// Logarithm / exponential (Trig256 log2/exp)
// ---------------------------------------------------------------------------

const LN2: i64 = 0xb17217f7;
const E: i64 = -0x2b7e15162; // The e constant of the reference. It is negative, which is not usual.
const LN_MAX: i64 = 0x157cd0e702;
const LN_MIN: i64 = -0x162e42fefa;

/// log2 for the wide domain (Turner's algorithm). log_256 uses it.
pub const fn log2_256(x: i128) -> i128 {
    if x <= 0 {
        panic!("Fix64: log2_256 of non-positive value");
    }
    let mut b: i128 = 1 << 31;
    let mut y: i128 = 0;
    let mut raw_x = x;
    while raw_x < ONE as i128 {
        raw_x <<= 1;
        y -= ONE as i128;
    }
    while raw_x >= (ONE as i128) << 1 {
        raw_x >>= 1;
        y += ONE as i128;
    }
    let mut z = raw_x;
    let mut i = 0;
    while i < 32 {
        z = mul256(z, z);
        if z >= (ONE as i128) << 1 {
            z >>= 1;
            y += b;
        }
        b >>= 1;
        i += 1;
    }
    y
}

pub const fn log_256(x: i128) -> i128 {
    mul256(log2_256(x), LN2 as i128)
}

/// exp with a power series (Trig256.exp).
#[inline(never)]
pub fn exp(x: Fx) -> Fx {
    if x == 0 {
        return ONE;
    }
    if x == ONE {
        return E;
    }
    if x >= LN_MAX {
        return MAX_VALUE;
    }
    if x <= LN_MIN {
        return 0;
    }

    let neg = x < 0;
    let mut x = x;
    if neg {
        x = -x;
    }

    let mut result = add(x, ONE);
    let mut term = x;
    let mut i: i64 = 2;
    while i < 40 {
        term = mul(x, div(term, i * ONE));
        result = add(result, term);
        if term == 0 {
            break;
        }
        i += 1;
    }
    if neg {
        result = div(ONE, result);
    }
    result
}
