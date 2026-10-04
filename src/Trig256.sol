// SPDX-License-Identifier: MIT
/* Copyright (c) Kohi Art Community, Inc. All rights reserved. */

/*
/*
///////////////////////////////////////////////////////////////////////////////////
//                                                                               //
//     @@@@@@@@@@@@@@                        @@@@                                //
//               @@@@                        @@@@ @@@@@@@@                       //
//               @@@@    @@@@@@@@@@@@@@@@    @@@@@@@          @@@@@@@@@@@@@@@@   //
//               @@@@                        @@@@                                //
//     @@@@@@@@@@@@@@                        @@@@@@@@@@@@@                       //
//               @@@@                          @@@@@@@@@@@                       //
//                                                                               //
///////////////////////////////////////////////////////////////////////////////////
*/
pragma solidity ^0.8.13;

import "./Fix64.sol";
import "./SinLut256.sol";

/*
    Trig256: trigonometric, logarithmic, and exponential functions over the
    Fix64 Q31.32 fixed-point format. sin/cos are computed via range reduction
    plus a 256-entry lookup table with linear interpolation (see SinLut256.sol);
    log2/log/exp use the power-series and binary-logarithm algorithms below;
    acos/atan/atan2 are series approximations adapted from FixedMath.NET.

    exp: Adapted from Petteri Aimonen's libfixmath

    See: https://github.com/PetteriAimonen/libfixmath
         https://github.com/PetteriAimonen/libfixmath/blob/master/LICENSE

    other functions: Adapted from Andre Slupik's FixedMath.NET
                     https://github.com/asik/FixedMath.Net/blob/master/LICENSE.txt

    THIRD PARTY NOTICES:
    ====================

    libfixmath is Copyright (c) 2011-2021 Flatmush <Flatmush@gmail.com>,
    Petteri Aimonen <Petteri.Aimonen@gmail.com>, & libfixmath AUTHORS

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    Copyright 2012 André Slupik

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    This project uses code from the log2fix library, which is under the following license:
    The MIT License (MIT)

    Copyright (c) 2015 Dan Moulding

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
*/

/*
    sin/cos/sqrt/clamp bodies below run inside `unchecked` blocks so
    int64/uint64 arithmetic wraps on overflow, matching the original
    reference implementation. See Fix64.sol for the same convention.
*/

/// @notice Trigonometric, logarithmic, and exponential functions over Fix64.
library Trig256 {
    int64 private constant LARGE_PI = 7244019458077122842;
    /// @dev ln(2) in Q31.32, used to convert log2() results to natural log.
    int64 private constant LN2 = 0xB17217F7;
    /// @dev Largest input to exp() that does not saturate the Q31.32 range.
    int64 private constant LN_MAX = 0x157CD0E702;
    /// @dev Smallest input to exp() before the result underflows to zero.
    int64 private constant LN_MIN = -0x162E42FEFA;
    /// @dev The value exp() returns as a fast-path shortcut for x == ONE,
    /// preserved bit-for-bit from the reference implementation.
    int64 private constant E = -0x2B7E15162;

    // Fix64.div((256 - 1) * Fix64.ONE, Fix64.PI_OVER_2), precomputed: the
    // long-division routine is far too expensive to rerun per sin() call.
    int64 private constant LUT_INTERVAL = 697236581115;

    /// @notice Sine of x, computed via range reduction into [0, PI/2] and a
    /// 256-entry lookup table with linear interpolation between entries.
    /// @param x Angle in radians, Q31.32.
    /// @return Sine of x, Q31.32, in [-ONE, ONE].
    function sin(int64 x) internal pure returns (int64) {
        unchecked {
            (int64 clamped, bool flipHorizontal, bool flipVertical) = clamp(x);

            int64 lutInterval = LUT_INTERVAL;
            int256 rawIndex = Fix64.mul_256(clamped, lutInterval);
            int64 roundedIndex = int64(Fix64.round(rawIndex));
            int64 indexError = Fix64.sub(int64(rawIndex), roundedIndex);

            roundedIndex = roundedIndex >> 32; /* FRACTIONAL_PLACES */

            int64 nearestValueIndex = flipHorizontal
                ? (256 - 1) - roundedIndex
                : roundedIndex;

            int64 nearestValue = SinLut256.sinlut(nearestValueIndex);

            int64 secondNearestValue = SinLut256.sinlut(
                flipHorizontal
                    ? (256 - 1) - roundedIndex - Fix64.sign(indexError)
                    : roundedIndex + Fix64.sign(indexError)
            );

            int64 delta = Fix64.mul(
                indexError,
                Fix64.abs(Fix64.sub(nearestValue, secondNearestValue))
            );
            int64 interpolatedValue = nearestValue +
                (flipHorizontal ? -delta : delta);
            int64 finalValue = flipVertical
                ? -interpolatedValue
                : interpolatedValue;

            return finalValue;
        }
    }

    /// @notice Cosine of x, via a phase shift into sin().
    /// @param x Angle in radians, Q31.32.
    /// @return Cosine of x, Q31.32, in [-ONE, ONE].
    function cos(int64 x) internal pure returns (int64) {
        unchecked {
            int64 xl = x;
            int64 angle;
            if (xl > 0) {
                angle = Fix64.add(xl, Fix64.sub(0 - Fix64.PI, Fix64.PI_OVER_2));
            } else {
                angle = Fix64.add(xl, Fix64.PI_OVER_2);
            }
            return sin(angle);
        }
    }

    /*
     * sin/cos against a memory-resident copy of the SinLut256 table (see
     * SinLut256.table()), for callers that cannot afford the ~2.6 KB inlined
     * selection tree that sinlut(int256) compiles to, e.g. contracts close to
     * the EIP-170 runtime size limit. Statement-for-statement identical to
     * sin(x)/cos(x) above; only the LUT access differs, and results are
     * bit-identical. If you change one variant, mirror the other.
     */
    /// @notice Sine of x, reading the sine table from memory at lutPtr instead
    /// of the inlined selection tree (see SinLut256.table()).
    /// @param x Angle in radians, Q31.32.
    /// @param lutPtr Pointer to a 256*8-byte, big-endian copy of the sine table.
    /// @return Sine of x, Q31.32, bit-identical to sin(x).
    function sin(int64 x, uint256 lutPtr) internal pure returns (int64) {
        unchecked {
            (int64 clamped, bool flipHorizontal, bool flipVertical) = clamp(x);

            int64 lutInterval = LUT_INTERVAL;
            int256 rawIndex = Fix64.mul_256(clamped, lutInterval);
            int64 roundedIndex = int64(Fix64.round(rawIndex));
            int64 indexError = Fix64.sub(int64(rawIndex), roundedIndex);

            roundedIndex = roundedIndex >> 32; /* FRACTIONAL_PLACES */

            int64 nearestValueIndex = flipHorizontal
                ? (256 - 1) - roundedIndex
                : roundedIndex;

            int64 nearestValue = SinLut256.sinlut(lutPtr, nearestValueIndex);

            int64 secondNearestValue = SinLut256.sinlut(
                lutPtr,
                flipHorizontal
                    ? (256 - 1) - roundedIndex - Fix64.sign(indexError)
                    : roundedIndex + Fix64.sign(indexError)
            );

            int64 delta = Fix64.mul(
                indexError,
                Fix64.abs(Fix64.sub(nearestValue, secondNearestValue))
            );
            int64 interpolatedValue = nearestValue +
                (flipHorizontal ? -delta : delta);
            int64 finalValue = flipVertical
                ? -interpolatedValue
                : interpolatedValue;

            return finalValue;
        }
    }

    /// @notice Cosine of x, reading the sine table from memory at lutPtr.
    /// @param x Angle in radians, Q31.32.
    /// @param lutPtr Pointer to a 256*8-byte, big-endian copy of the sine table.
    /// @return Cosine of x, Q31.32, bit-identical to cos(x).
    function cos(int64 x, uint256 lutPtr) internal pure returns (int64) {
        unchecked {
            int64 xl = x;
            int64 angle;
            if (xl > 0) {
                angle = Fix64.add(xl, Fix64.sub(0 - Fix64.PI, Fix64.PI_OVER_2));
            } else {
                angle = Fix64.add(xl, Fix64.PI_OVER_2);
            }
            return sin(angle, lutPtr);
        }
    }

    /// @notice Square root of a Q31.32 value.
    /// @dev Digit-by-digit binary square root, run twice over the 64-bit
    /// word (once per 32-bit half) so the result comes out correctly
    /// scaled in Q31.32 rather than needing a separate rescale step.
    /// @custom:reverts NegativeValuePassed if x < 0.
    function sqrt(int64 x) internal pure returns (int64) {
        unchecked {
            int64 xl = x;
            if (xl < 0) revert NegativeValuePassed();

            uint64 num = uint64(xl);
            uint64 result = uint64(0);
            uint64 bit = uint64(1) << (64 - 2);

            while (bit > num) bit >>= 2;
            for (uint8 i = 0; i < 2; ++i) {
                while (bit != 0) {
                    if (num >= result + bit) {
                        num -= result + bit;
                        result = (result >> 1) + bit;
                    } else {
                        result = result >> 1;
                    }

                    bit >>= 2;
                }

                if (i == 0) {
                    if (num > (uint64(1) << (64 / 2)) - 1) {
                        num -= result;
                        num = (num << (64 / 2)) - uint64(0x80000000);
                        result = (result << (64 / 2)) + uint64(0x80000000);
                    } else {
                        num <<= 64 / 2;
                        result <<= 64 / 2;
                    }

                    bit = uint64(1) << (64 / 2 - 2);
                }
            }

            if (num > result) ++result;
            return int64(result);
        }
    }

    /// @notice Base-2 logarithm of x, computed at int256 precision.
    /// @param x A positive Q31.32 value.
    /// @return log2(x) in Q31.32.
    /// @custom:reverts NegativeValuePassed if x <= 0.
    function log2_256(int256 x) public pure returns (int256) {
        if (x <= 0) {
            revert NegativeValuePassed();
        }

        // This implementation is based on Clay. S. Turner's fast binary logarithm
        // algorithm (C. S. Turner,  "A Fast Binary Logarithm Algorithm", IEEE Signal
        //     Processing Mag., pp. 124,140, Sep. 2010.)

        int256 b = 1 << 31; // FRACTIONAL_PLACES - 1
        int256 y = 0;

        int256 rawX = x;
        while (rawX < Fix64.ONE) {
            rawX <<= 1;
            y -= Fix64.ONE;
        }

        while (rawX >= Fix64.ONE << 1) {
            rawX >>= 1;
            y += Fix64.ONE;
        }

        int256 z = rawX;

        for (uint8 i = 0; i < 32 /* FRACTIONAL_PLACES */; i++) {
            z = Fix64.mul_256(z, z);
            if (z >= Fix64.ONE << 1) {
                z = z >> 1;
                y += b;
            }
            b >>= 1;
        }

        return y;
    }

    /// @notice Natural logarithm of x, computed at int256 precision.
    /// @param x A positive Q31.32 value.
    /// @return ln(x) in Q31.32.
    /// @custom:reverts NegativeValuePassed if x <= 0.
    function log_256(int256 x) public pure returns (int256) {
        return Fix64.mul_256(log2_256(x), LN2);
    }

    /// @notice Base-2 logarithm of x.
    /// @param x A positive Q31.32 value.
    /// @return log2(x) in Q31.32.
    /// @custom:reverts NegativeValuePassed if x <= 0.
    function log2(int64 x) public pure returns (int64) {
        if (x <= 0) revert NegativeValuePassed();

        // This implementation is based on Clay. S. Turner's fast binary logarithm
        // algorithm (C. S. Turner,  "A Fast Binary Logarithm Algorithm", IEEE Signal
        //     Processing Mag., pp. 124,140, Sep. 2010.)

        int64 b = 1 << 31; // FRACTIONAL_PLACES - 1
        int64 y = 0;

        int64 rawX = x;
        while (rawX < Fix64.ONE) {
            rawX <<= 1;
            y -= Fix64.ONE;
        }

        while (rawX >= Fix64.ONE << 1) {
            rawX >>= 1;
            y += Fix64.ONE;
        }

        int64 z = rawX;

        for (int32 i = 0; i < Fix64.FRACTIONAL_PLACES; i++) {
            z = Fix64.mul(z, z);
            if (z >= Fix64.ONE << 1) {
                z = z >> 1;
                y += b;
            }

            b >>= 1;
        }

        return y;
    }

    /// @notice Natural logarithm of x.
    /// @param x A positive Q31.32 value.
    /// @return ln(x) in Q31.32.
    /// @custom:reverts NegativeValuePassed if x <= 0.
    function log(int64 x) public pure returns (int64) {
        return Fix64.mul(log2(x), LN2);
    }

    /// @notice e raised to the power of x.
    /// @param x Exponent, Q31.32.
    /// @return exp(x) in Q31.32; MAX_VALUE if x is large enough to overflow,
    /// 0 if x is small enough to underflow.
    function exp(int64 x) public pure returns (int64) {
        if (x == 0) return Fix64.ONE;
        if (x == Fix64.ONE) return E;
        if (x >= LN_MAX) return Fix64.MAX_VALUE;
        if (x <= LN_MIN) return 0;

        /* The algorithm is based on the power series for exp(x):
         * http://en.wikipedia.org/wiki/Exponential_function#Formal_definition
         *
         * From term n, we get term n+1 by multiplying with x/n.
         * When the sum term drops to zero, we can stop summing.
         */

        // The power-series converges much faster on positive values
        // and exp(-x) = 1/exp(x).

        bool neg = (x < 0);
        if (neg) x = -x;

        int64 result = Fix64.add(int64(x), Fix64.ONE);
        int64 term = x;

        for (uint32 i = 2; i < 40; i++) {
            term = Fix64.mul(x, Fix64.div(term, int32(i) * Fix64.ONE));
            result = Fix64.add(result, int64(term));
            if (term == 0) break;
        }

        if (neg) {
            result = Fix64.div(Fix64.ONE, result);
        }

        return result;
    }

    /*
     * Compact cross-contract stubs for this library's cold `public` fns.
     * The functions stay public (deployed once in the linked Trig256
     * library); these wrappers replace solc's per-site delegatecall stubs
     * with one shared staticcall sequence: the callees are pure, so a
     * direct staticcall against the library address returns identical
     * bytes with none of the generated ABI ceremony. The fixed callees
     * always return exactly 32 bytes on success, so returndata length
     * needs no validation; failures bubble verbatim.
     */
    /// @dev Calls a single-int-argument public function on this library's own
    /// deployed code via staticcall, bypassing the ABI-encoded delegatecall
    /// stub solc would otherwise generate at each call site.
    function _ext1(bytes4 sel, int256 x) private view returns (int256 r) {
        address a = address(Trig256);
        assembly {
            let p := mload(0x40)
            mstore(p, sel)
            mstore(add(p, 4), x)
            if iszero(staticcall(gas(), a, p, 36, p, 32)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            r := mload(p)
        }
    }

    /// @dev Cross-contract call to log(), see _ext1.
    function extLog(int64 x) internal view returns (int64) {
        return int64(_ext1(Trig256.log.selector, x));
    }

    /// @dev Cross-contract call to exp(), see _ext1.
    function extExp(int64 x) internal view returns (int64) {
        return int64(_ext1(Trig256.exp.selector, x));
    }

    /// @dev Cross-contract call to acos(), see _ext1.
    function extAcos(int64 x) internal view returns (int64) {
        return int64(_ext1(Trig256.acos.selector, x));
    }

    /// @dev Cross-contract call to log_256(), see _ext1.
    function extLog256(int256 x) internal view returns (int256) {
        return _ext1(Trig256.log_256.selector, x);
    }

    /// @dev Cross-contract call to atan2(), same staticcall approach as
    /// _ext1 but inlined for the two-argument signature.
    function extAtan2(int64 y, int64 x) internal view returns (int64 r) {
        address a = address(Trig256);
        bytes4 sel = Trig256.atan2.selector;
        assembly {
            let p := mload(0x40)
            mstore(p, sel)
            mstore(add(p, 4), y)
            mstore(add(p, 36), x)
            if iszero(staticcall(gas(), a, p, 68, p, 32)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            r := mload(p)
        }
    }

    /// @dev Range-reduces x into [0, PI/2], the domain the sine lookup table
    /// covers, and records which reflections are needed to reconstruct the
    /// value in the original quadrant.
    /// @return clamped x reduced into [0, PI/2].
    /// @return flipHorizontal True if x fell in the second half of [0, PI].
    /// @return flipVertical True if x fell in [PI, 2*PI).
    function clamp(int64 x) internal pure returns (int64, bool, bool) {
        unchecked {
            int64 clamped2Pi = x;
            for (uint8 i = 0; i < 29; ++i) {
                clamped2Pi %= LARGE_PI >> i;
            }
            if (x < 0) {
                clamped2Pi += Fix64.TWO_PI;
            }

            bool flipVertical = clamped2Pi >= Fix64.PI;
            int64 clampedPi = clamped2Pi;
            while (clampedPi >= Fix64.PI) {
                clampedPi -= Fix64.PI;
            }

            bool flipHorizontal = clampedPi >= Fix64.PI_OVER_2;

            int64 clampedPiOver2 = clampedPi;
            if (clampedPiOver2 >= Fix64.PI_OVER_2)
                clampedPiOver2 -= Fix64.PI_OVER_2;

            return (clampedPiOver2, flipHorizontal, flipVertical);
        }
    }

    /// @notice Arc cosine of x, via atan(sqrt(1 - x^2) / x).
    /// @param x A Q31.32 value in [-ONE, ONE].
    /// @return result Angle in radians, Q31.32, in [0, PI].
    /// @custom:reverts "invalid range for x" if x is outside [-ONE, ONE].
    function acos(int64 x) public pure returns (int64 result) {
        if (x < -Fix64.ONE || x > Fix64.ONE) revert("invalid range for x");
        if (x == 0) return Fix64.PI_OVER_2;

        int64 t1 = Fix64.ONE - Fix64.mul(x, x);
        int64 t2 = Fix64.div(sqrt(t1), x);

        result = atan(t2);
        return x < 0 ? result + Fix64.PI : result;
    }

    /// @notice Arc tangent of z, via a continued-fraction series. Values
    /// with |z| > 1 are computed as PI/2 - atan(1/z) for faster convergence.
    /// @param z Q31.32.
    /// @return result Angle in radians, Q31.32, in (-PI/2, PI/2).
    function atan(int64 z) public pure returns (int64 result) {
        if (z == 0) return 0;

        bool neg = z < 0;
        if (neg) z = -z;

        int64 two = Fix64.TWO;
        int64 three = Fix64.THREE;

        bool invert = z > Fix64.ONE;
        if (invert) z = Fix64.div(Fix64.ONE, z);

        result = Fix64.ONE;
        int64 term = Fix64.ONE;

        int64 zSq = Fix64.mul(z, z);
        int64 zSq2 = Fix64.mul(zSq, two);
        int64 zSqPlusOne = Fix64.add(zSq, Fix64.ONE);
        int64 zSq12 = Fix64.mul(zSqPlusOne, two);
        int64 dividend = zSq2;
        int64 divisor = Fix64.mul(zSqPlusOne, three);

        for (uint8 i = 2; i < 30; ++i) {
            term = Fix64.mul(term, Fix64.div(dividend, divisor));
            result = Fix64.add(result, term);

            dividend = Fix64.add(dividend, zSq2);
            divisor = Fix64.add(divisor, zSq12);

            if (term == 0) break;
        }

        result = Fix64.mul(result, Fix64.div(z, zSqPlusOne));

        if (invert) {
            result = Fix64.sub(Fix64.PI_OVER_2, result);
        }

        if (neg) {
            result = -result;
        }

        return result;
    }

    /// @notice Angle of the point (x, y) from the positive x-axis, via a
    /// rational polynomial approximation (a separate algorithm from atan()).
    /// @param y Q31.32.
    /// @param x Q31.32.
    /// @return result Angle in radians, Q31.32, in (-PI, PI].
    function atan2(int64 y, int64 x) public pure returns (int64 result) {
        int64 e = 1202590848; /* 0.28 */
        int64 yl = y;
        int64 xl = x;

        if (xl == 0) {
            if (yl > 0) {
                return Fix64.PI_OVER_2;
            }
            if (yl == 0) {
                return 0;
            }
            return -Fix64.PI_OVER_2;
        }

        int64 z = Fix64.div(y, x);

        if (
            Fix64.add(Fix64.ONE, Fix64.mul(e, Fix64.mul(z, z))) ==
            type(int64).max
        ) {
            return y < 0 ? -Fix64.PI_OVER_2 : Fix64.PI_OVER_2;
        }

        if (Fix64.abs(z) < Fix64.ONE) {
            result = Fix64.div(
                z,
                Fix64.add(Fix64.ONE, Fix64.mul(e, Fix64.mul(z, z)))
            );
            if (xl < 0) {
                if (yl < 0) {
                    return Fix64.sub(result, Fix64.PI);
                }

                return Fix64.add(result, Fix64.PI);
            }
        } else {
            result = Fix64.sub(
                Fix64.PI_OVER_2,
                Fix64.div(z, Fix64.add(Fix64.mul(z, z), e))
            );

            if (yl < 0) {
                return Fix64.sub(result, Fix64.PI);
            }
        }
    }
}
