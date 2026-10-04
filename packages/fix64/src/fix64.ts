/*
 * Fix64: signed Q31.32 fixed-point math. It is a bit-for-bit port of
 * Fix64.sol / Trig256.sol from Kohi Art Community. Those libraries are
 * adaptations of FixedMath.Net and libfixmath (refer to the licenses in the
 * Solidity sources).
 *
 * Each function in this file must give results that are byte-identical to the
 * Solidity libraries. This file is the base of determinism for the KVM. Do not
 * change the rounding and do not simplify the code. A difference breaks the
 * rendering between backends.
 */
import { SINLUT256 } from "./sinlut.js";

export type Fx = bigint; // A Q31.32 value in an int64.

export const ONE = 4294967296n; // 1 << 32
export const TWO = ONE * 2n;
export const THREE = ONE * 3n;
export const PI = 0x3243f6a88n;
export const TWO_PI = 0x6487ed511n;
export const PI_OVER_2 = 0x1921fb544n;
export const MAX_VALUE = (1n << 63n) - 1n;
export const MIN_VALUE = -(1n << 63n);

const MASK64 = (1n << 64n) - 1n;
const LARGE_PI = 7244019458077122842n;

const i64 = (x: bigint): bigint => BigInt.asIntN(64, x);
const u64 = (x: bigint): bigint => BigInt.asUintN(64, x);

export function fromInt(n: number): Fx {
  return BigInt(n) * ONE;
}

/** Use this only to write a program (for assembler constants). The interpreter does not use it. */
export function fromFloat(f: number): Fx {
  return i64(BigInt(Math.round(f * 4294967296)));
}

export function toFloat(x: Fx): number {
  return Number(x) / 4294967296;
}

/** Addition with saturation (Fix64.add). */
export function add(x: Fx, y: Fx): Fx {
  const sum = i64(x + y);
  if ((~(x ^ y) & (x ^ sum) & MIN_VALUE) !== 0n) return x > 0n ? MAX_VALUE : MIN_VALUE;
  return sum;
}

/** Subtraction with saturation (Fix64.sub). */
export function sub(x: Fx, y: Fx): Fx {
  const diff = i64(x - y);
  if (((x ^ y) & (x ^ diff) & MIN_VALUE) !== 0n) return x < 0n ? MIN_VALUE : MAX_VALUE;
  return diff;
}

/** Multiplication that wraps and truncates (Fix64.mul). It is equal to the hi/lo 32-bit decomposition. */
export function mul(x: Fx, y: Fx): Fx {
  // This is equal to the four-part decomposition of FixedMath.NET with an
  // int64 wrap for each part. The decomposition is an integer identity, and
  // the intermediate wraps have no effect mod 2^64. Thus, the wrapped
  // truncating product equals floor(x*y / 2^32) wrapped to int64.
  return i64((x * y) >> 32n);
}

/** The 256-bit variant. The index calculation of Trig256.sin uses it. */
export function mul256(x: bigint, y: bigint): bigint {
  const xlo = x & 0xffffffffn;
  const xhi = x >> 32n;
  const ylo = y & 0xffffffffn;
  const yhi = y >> 32n;

  const lolo = BigInt.asUintN(256, xlo * ylo);
  const lohi = BigInt.asIntN(256, xlo * yhi);
  const hilo = BigInt.asIntN(256, xhi * ylo);
  const hihi = BigInt.asIntN(256, xhi * yhi);

  const loResult = lolo >> 32n;
  const hiResult = BigInt.asIntN(256, hihi << 32n);

  return BigInt.asIntN(256, loResult + lohi + hilo + hiResult);
}

/** Long division with rounding and saturation (Fix64.div). Throws if y == 0. */
export function div(x: Fx, y: Fx): Fx {
  if (y === 0n) throw new Error("Fix64: division by zero");

  // This is the closed form of the restoring long division of FixedMath.NET.
  // The loop accumulates floor(|x| * 2^33 / |y|). It saturates when that
  // value overflows 64 bits, and it rounds the extra bit half-up.
  const ax = x >= 0n ? x : -x;
  const ay = y >= 0n ? y : -y;
  const q = (ax << 33n) / ay;
  if (q > MASK64) {
    return ((x ^ y) & MIN_VALUE) === 0n ? MAX_VALUE : MIN_VALUE;
  }
  let result = i64((q + 1n) >> 1n);
  if (((x ^ y) & MIN_VALUE) !== 0n) result = -result;
  return i64(result);
}

export function floor(x: bigint): Fx {
  return i64(x & ~0xffffffffn);
}

export function round256(x: bigint): bigint {
  const fractionalPart = x & 0x00000000ffffffffn;
  const integralPart = floor(x);
  if (fractionalPart < 0x80000000n) return integralPart;
  if (fractionalPart > 0x80000000n) return integralPart + ONE;
  if ((integralPart & ONE) === 0n) return integralPart;
  return integralPart + ONE;
}

export function sign(x: Fx): bigint {
  return x === 0n ? 0n : x > 0n ? 1n : -1n;
}

export function abs(x: Fx): Fx {
  const mask = x >> 63n;
  return i64((x + mask) ^ mask);
}

export function max(a: Fx, b: Fx): Fx {
  return a >= b ? a : b;
}

export function min(a: Fx, b: Fx): Fx {
  return a < b ? a : b;
}

export function constrain(n: Fx, low: Fx, high: Fx): Fx {
  return max(min(n, high), low);
}

// ---------------------------------------------------------------------------
// Trig256 (sin / cos / sqrt). This is a port of Trig256.sol.
// ---------------------------------------------------------------------------

/**
 * Reduces the argument to [0, PI/2) and gives the quadrant flip flags
 * (Trig256.clamp). The sequence of moduli against LARGE_PI >> i reduces a
 * large argument and keeps the precision.
 */
export function clampAngle(x: Fx): { clamped: Fx; flipHorizontal: boolean; flipVertical: boolean } {
  let clamped2Pi = x;
  for (let i = 0n; i < 29n; ++i) {
    clamped2Pi %= LARGE_PI >> i;
  }
  if (x < 0n) clamped2Pi += TWO_PI;

  const flipVertical = clamped2Pi >= PI;
  let clampedPi = clamped2Pi;
  while (clampedPi >= PI) clampedPi -= PI;

  const flipHorizontal = clampedPi >= PI_OVER_2;

  let clampedPiOver2 = clampedPi;
  if (clampedPiOver2 >= PI_OVER_2) clampedPiOver2 -= PI_OVER_2;

  return { clamped: clampedPiOver2, flipHorizontal, flipVertical };
}

/**
 * This function has the same out-of-range behavior as the binary search tree
 * of SinLut256.sinlut. A negative index gives entry 1. An index above 255
 * gives entry 255.
 */
function sinlut(i: bigint): Fx {
  if (i < 0n) return SINLUT256[1]!;
  if (i > 255n) return SINLUT256[255]!;
  return SINLUT256[Number(i)]!;
}

const LUT_INTERVAL = div(255n * ONE, PI_OVER_2); // (256 - 1) * ONE / (PI/2)

export function sin(x: Fx): Fx {
  const { clamped, flipHorizontal, flipVertical } = clampAngle(x);

  const rawIndex = mul256(clamped, LUT_INTERVAL);
  let roundedIndex = i64(round256(rawIndex));
  const indexError = sub(i64(rawIndex), roundedIndex);

  roundedIndex = roundedIndex >> 32n;

  const nearestValueIndex = flipHorizontal ? 255n - roundedIndex : roundedIndex;
  const nearestValue = sinlut(nearestValueIndex);

  const secondNearestValue = sinlut(
    flipHorizontal ? 255n - roundedIndex - sign(indexError) : roundedIndex + sign(indexError),
  );

  const delta = mul(indexError, abs(sub(nearestValue, secondNearestValue)));
  const interpolatedValue = i64(nearestValue + (flipHorizontal ? -delta : delta));
  return flipVertical ? i64(-interpolatedValue) : interpolatedValue;
}

export function cos(x: Fx): Fx {
  let angle: Fx;
  if (x > 0n) {
    angle = add(x, sub(0n - PI, PI_OVER_2));
  } else {
    angle = add(x, PI_OVER_2);
  }
  return sin(angle);
}

/** Fixed-point square root (Trig256.sqrt). Throws if the input is negative. */
export function sqrt(x: Fx): Fx {
  if (x < 0n) throw new Error("Fix64: sqrt of negative value");

  let num = u64(x);
  let result = 0n;
  let bit = 1n << 62n;

  while (bit > num) bit >>= 2n;
  for (let i = 0; i < 2; ++i) {
    while (bit !== 0n) {
      if (num >= result + bit) {
        num -= result + bit;
        result = (result >> 1n) + bit;
      } else {
        result = result >> 1n;
      }
      bit >>= 2n;
    }

    if (i === 0) {
      if (num > (1n << 32n) - 1n) {
        num -= result;
        num = u64(num << 32n) - 0x80000000n;
        result = u64(result << 32n) + 0x80000000n;
      } else {
        num = u64(num << 32n);
        result = u64(result << 32n);
      }
      bit = 1n << 30n;
    }
  }

  if (num > result) ++result;
  return i64(result);
}

// ---------------------------------------------------------------------------
// Logarithm / exponential (Trig256 log2/log/exp). The LCG64 table build of
// NoiseV1 and RandomV1.nextGaussian use these functions. This is a port of
// Kohi's Trig256.
// ---------------------------------------------------------------------------

const LN2 = 0xb17217f7n;
const E = -0x2b7e15162n;
const LN_MAX = 0x157cd0e702n;
const LN_MIN = -0x162e42fefan;

/** log2 for int256 (Turner's algorithm). log_256 uses it. */
export function log2_256(x: bigint): bigint {
  if (x <= 0n) throw new Error("Fix64: log2_256 of non-positive value");
  let b = 1n << 31n;
  let y = 0n;
  let rawX = x;
  while (rawX < ONE) {
    rawX <<= 1n;
    y -= ONE;
  }
  while (rawX >= ONE << 1n) {
    rawX >>= 1n;
    y += ONE;
  }
  let z = rawX;
  for (let i = 0; i < 32; i++) {
    z = mul256(z, z);
    if (z >= ONE << 1n) {
      z = z >> 1n;
      y += b;
    }
    b >>= 1n;
  }
  return y;
}

export function log_256(x: bigint): bigint {
  return mul256(log2_256(x), LN2);
}

/** log2 for int64 (with Fix64.mul). log uses it. */
export function log2(x: Fx): Fx {
  if (x <= 0n) throw new Error("Fix64: log2 of non-positive value");
  let b = 1n << 31n;
  let y = 0n;
  let rawX = x;
  while (rawX < ONE) {
    rawX = i64(rawX << 1n);
    y -= ONE;
  }
  while (rawX >= ONE << 1n) {
    rawX >>= 1n;
    y += ONE;
  }
  let z = rawX;
  for (let i = 0; i < 32; i++) {
    z = mul(z, z);
    if (z >= ONE << 1n) {
      z = z >> 1n;
      y += b;
    }
    b >>= 1n;
  }
  return i64(y);
}

export function log(x: Fx): Fx {
  return mul(log2(x), LN2);
}

/** exp with a power series (Trig256.exp). */
export function exp(x: Fx): Fx {
  if (x === 0n) return ONE;
  if (x === ONE) return E;
  if (x >= LN_MAX) return MAX_VALUE;
  if (x <= LN_MIN) return 0n;

  const neg = x < 0n;
  if (neg) x = -x;

  let result = add(x, ONE);
  let term = x;
  for (let i = 2n; i < 40n; i++) {
    term = mul(x, div(term, i * ONE));
    result = add(result, term);
    if (term === 0n) break;
  }
  if (neg) result = div(ONE, result);
  return result;
}

// ---------------------------------------------------------------------------
// Inverse trig (Trig256.atan / atan2 / acos). This is a bit-for-bit port of
// Trig256.sol for the opcodes of the p5 subset (ATAN2/ASIN/ACOS).
// ---------------------------------------------------------------------------

/** Trig256.atan: arctangent with a series. This is an exact port. */
export function atan(z: Fx): Fx {
  if (z === 0n) return 0n;
  const neg = z < 0n;
  if (neg) z = i64(-z);
  const invert = z > ONE;
  if (invert) z = div(ONE, z);
  let result = ONE;
  let term = ONE;
  const zSq = mul(z, z);
  const zSq2 = mul(zSq, TWO);
  const zSqPlusOne = add(zSq, ONE);
  const zSq12 = mul(zSqPlusOne, TWO);
  let dividend = zSq2;
  let divisor = mul(zSqPlusOne, THREE);
  for (let i = 2; i < 30; i++) {
    term = mul(term, div(dividend, divisor));
    result = add(result, term);
    dividend = add(dividend, zSq2);
    divisor = add(divisor, zSq12);
    if (term === 0n) break;
  }
  result = mul(result, div(z, zSqPlusOne));
  if (invert) result = sub(PI_OVER_2, result);
  if (neg) result = i64(-result);
  return result;
}

/** Trig256.atan2: a fast approximation with the constant 0.28. This is an exact port. */
export function atan2(y: Fx, x: Fx): Fx {
  const e = 1202590848n; // 0.28
  if (x === 0n) {
    if (y > 0n) return PI_OVER_2;
    if (y === 0n) return 0n;
    return i64(-PI_OVER_2);
  }
  const z = div(y, x);
  if (add(ONE, mul(e, mul(z, z))) === MAX_VALUE) {
    return y < 0n ? i64(-PI_OVER_2) : PI_OVER_2;
  }
  let result: Fx;
  if (abs(z) < ONE) {
    result = div(z, add(ONE, mul(e, mul(z, z))));
    if (x < 0n) {
      if (y < 0n) return sub(result, PI);
      return add(result, PI);
    }
  } else {
    result = sub(PI_OVER_2, div(z, add(mul(z, z), e)));
    if (y < 0n) return sub(result, PI);
  }
  return result;
}

/** Trig256.acos. This is an exact port. The caller must clamp x to [-ONE, ONE].
 *  The ACOS/ASIN opcodes constrain x first. Trig256 reverts when x is out of
 *  range. */
export function acos(x: Fx): Fx {
  if (x === 0n) return PI_OVER_2;
  const t1 = i64(ONE - mul(x, x));
  const t2 = div(sqrt(t1), x);
  const result = atan(t2);
  return x < 0n ? i64(result + PI) : result;
}

/**
 * FL32 (Op.FL32): gives the IEEE binary32 value nearest to x, with ties to even,
 * as a Fix64.
 *
 * x is exact in Q31.32, so this function rounds only one time. Thus, the result
 * is the true float32 rounding and not an approximation that is rounded two
 * times.
 *
 * Returns null when 0 < |x| < 2^-9. In that range, the ulp of the binary32
 * result (2^(e-23)) is smaller than the 2^-32 of Q31.32. Thus, Q31.32 cannot
 * represent the answer. The interpreter faults on null. It must not round two
 * times. Callers multiply such values by a power of two before the call (fl32
 * is scale-invariant under powers of two).
 */
export function fl32(x: Fx): Fx | null {
  if (x === 0n) return 0n;
  const neg = x < 0n;
  const a = neg ? -x : x;
  // L is the bit length of the raw magnitude: 2^(L-1) <= a < 2^L, and
  // value = a / 2^32. Thus, the binade is e = L - 33 and the ulp in raw units
  // is 2^(L - 24).
  const shift = BigInt(a.toString(2).length - 24);
  if (shift < 0n) return null; // e < -9: Q31.32 cannot represent the result. Fault, and do not round two times.
  let r: bigint;
  if (shift === 0n) {
    r = a; // The value is already a 24-bit mantissa.
  } else {
    const q = a >> shift;
    const rem = a - (q << shift);
    const half = 1n << (shift - 1n);
    // Round half to even. A carry to 2^24 is permitted: it is the next binade and is still exact.
    r = rem > half || (rem === half && (q & 1n) === 1n) ? (q + 1n) << shift : q << shift;
  }
  return neg ? -r : r;
}
