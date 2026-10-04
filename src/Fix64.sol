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

/*
    Fix64: signed fixed-point arithmetic in Q31.32 format (a 64-bit two's
    complement integer with 32 fractional bits, so 1.0 is represented as
    1 << 32). This library provides the core operators, add/sub/mul/div,
    floor/round, sign/abs, min/max, and clamping/mapping helpers, that the
    rest of this codebase's trigonometric and logarithmic functions build on.

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
    The arithmetic below runs inside `unchecked` blocks so that int64/uint64
    operations wrap on overflow (two's complement), matching the original
    FixedMath.NET reference behavior. Solidity's default checked arithmetic
    would revert on exactly the wraps and saturations this format relies on.
*/

import "./Errors.sol";

/// @notice Signed fixed-point arithmetic in Q31.32 format (32 fractional bits).
library Fix64 {
    /// @notice Number of fractional bits in the Q31.32 representation.
    int64 public constant FRACTIONAL_PLACES = 32;
    /// @notice The fixed-point representation of 1.0 (1 << FRACTIONAL_PLACES).
    int64 public constant ONE = 4294967296; // 1 << FRACTIONAL_PLACES
    int64 public constant TWO = ONE * 2;
    int64 public constant THREE = ONE * 3;
    /// @notice Pi, in Q31.32.
    int64 public constant PI = 0x3243F6A88;
    /// @notice 2*Pi, in Q31.32.
    int64 public constant TWO_PI = 0x6487ED511;
    /// @notice The largest representable Fix64 value.
    int64 public constant MAX_VALUE = type(int64).max;
    /// @notice The smallest representable Fix64 value.
    int64 public constant MIN_VALUE = type(int64).min;
    /// @notice Pi / 2, in Q31.32.
    int64 public constant PI_OVER_2 = 0x1921FB544;

    /// @dev Counts leading zero bits in a 64-bit word, for bit-scan style
    /// routines. Does not handle x == 0 (the scan never terminates).
    function countLeadingZeros(uint64 x) internal pure returns (int64) {
        unchecked {
            int64 result = 0;
            while ((x & 0xF000000000000000) == 0) {
                result += 4;
                x <<= 4;
            }
            while ((x & 0x8000000000000000) == 0) {
                result += 1;
                x <<= 1;
            }
            return result;
        }
    }

    /*
     * div() and mul() are closed forms of the original FixedMath.NET
     * loop/decomposition implementations, bit-identical for every input:
     * the long division computes exactly floor(|x|*2^33/|y|) with
     * saturation and half-up rounding of the extra bit, and mul_256's
     * four-part decomposition absorbs its intermediate wraps mod 2^64.
     */

    /// @notice Divides x by y in Q31.32, rounding the result half up.
    /// @dev Saturates to MAX_VALUE/MIN_VALUE on overflow.
    /// @return The fixed-point quotient x / y.
    /// @custom:reverts AttemptedToDivideByZero if y == 0.
    function div(int64 x, int64 y) internal pure returns (int64) {
        unchecked {
            if (y == 0) {
                revert AttemptedToDivideByZero();
            }

            uint256 ax = uint64(x >= 0 ? x : -x);
            uint256 ay = uint64(y >= 0 ? y : -y);
            uint256 q = (ax << 33) / ay;
            if (q > type(uint64).max) {
                return ((x ^ y) & MIN_VALUE) == 0 ? MAX_VALUE : MIN_VALUE;
            }
            int64 result = int64(uint64((q + 1) >> 1));
            if (((x ^ y) & MIN_VALUE) != 0) {
                result = -result;
            }

            return result;
        }
    }

    /// @notice Multiplies x by y in Q31.32.
    /// @dev Widens to int256 for the multiply, then rescales; wraps on
    /// overflow rather than saturating (matches the original reference).
    /// @return The fixed-point product x * y.
    function mul(int64 x, int64 y) internal pure returns (int64) {
        unchecked {
            return int64(int256((int256(x) * int256(y)) >> 32));
        }
    }

    /// @notice Multiplies two Q31.32 values without truncating to int64.
    /// @dev Splits each operand into high/low 32-bit halves and sums the
    /// four partial products, so the result stays exact in int256 instead
    /// of wrapping the way mul() does. Used where intermediate precision
    /// matters, e.g. squaring a value repeatedly in log2().
    /// @return The fixed-point product x * y as an int256.
    function mul_256(int256 x, int256 y) internal pure returns (int256) {
        unchecked {
            int256 xl = x;
            int256 yl = y;

            uint256 xlo = uint256((xl & int256(0x00000000FFFFFFFF)));
            int256 xhi = xl >> 32; // FRACTIONAL_PLACES
            uint256 ylo = uint256(yl & int256(0x00000000FFFFFFFF));
            int256 yhi = yl >> 32; // FRACTIONAL_PLACES

            uint256 lolo = xlo * ylo;
            int256 lohi = int256(xlo) * yhi;
            int256 hilo = xhi * int256(ylo);
            int256 hihi = xhi * yhi;

            uint256 loResult = lolo >> 32; // FRACTIONAL_PLACES
            int256 midResult1 = lohi;
            int256 midResult2 = hilo;
            int256 hiResult = hihi << 32; // FRACTIONAL_PLACES

            int256 sum = int256(loResult) + midResult1 + midResult2 + hiResult;

            return sum;
        }
    }

    /// @notice Truncates a Q31.32 value down to the nearest whole number.
    /// @dev Zeroes the fractional bits; rounds toward negative infinity.
    function floor(int256 x) internal pure returns (int64) {
        unchecked {
            return int64(x & 0xFFFFFFFF00000000);
        }
    }

    /// @notice Rounds a Q31.32 value to the nearest whole number.
    /// @dev Ties (fractional part exactly 0.5) round to even, matching
    /// IEEE-754 banker's rounding.
    function round(int256 x) internal pure returns (int256) {
        unchecked {
            int256 fractionalPart = x & 0x00000000FFFFFFFF;
            int256 integralPart = floor(x);
            if (fractionalPart < 0x80000000) return integralPart;
            if (fractionalPart > 0x80000000) return integralPart + ONE;
            if ((integralPart & ONE) == 0) return integralPart;
            return integralPart + ONE;
        }
    }

    /// @notice Subtracts y from x, saturating instead of wrapping on overflow.
    /// @return x - y, clamped to [MIN_VALUE, MAX_VALUE].
    function sub(int64 x, int64 y) internal pure returns (int64) {
        unchecked {
            int64 xl = x;
            int64 yl = y;
            int64 diff = xl - yl;
            if (((xl ^ yl) & (xl ^ diff) & MIN_VALUE) != 0)
                diff = xl < 0 ? MIN_VALUE : MAX_VALUE;
            return diff;
        }
    }

    /// @notice Adds x and y, saturating instead of wrapping on overflow.
    /// @return x + y, clamped to [MIN_VALUE, MAX_VALUE].
    function add(int64 x, int64 y) internal pure returns (int64) {
        unchecked {
            int64 xl = x;
            int64 yl = y;
            int64 sum = xl + yl;
            if ((~(xl ^ yl) & (xl ^ sum) & MIN_VALUE) != 0)
                sum = xl > 0 ? MAX_VALUE : MIN_VALUE;
            return sum;
        }
    }

    /// @notice The sign of x.
    /// @return -1, 0, or 1.
    function sign(int64 x) internal pure returns (int8) {
        return x == int8(0) ? int8(0) : x > int8(0) ? int8(1) : int8(-1);
    }

    /// @notice The absolute value of x.
    /// @dev Branchless via the sign-mask trick; MIN_VALUE has no positive
    /// counterpart and wraps back to itself under the unchecked negation.
    function abs(int64 x) internal pure returns (int64) {
        unchecked {
            int64 mask = x >> 63;
            return (x + mask) ^ mask;
        }
    }

    /// @notice The larger of a and b.
    function max(int64 a, int64 b) internal pure returns (int64) {
        return a >= b ? a : b;
    }

    /// @notice The smaller of a and b.
    function min(int64 a, int64 b) internal pure returns (int64) {
        return a < b ? a : b;
    }

    /// @notice Linearly maps n from the range [start1, stop1] to [start2, stop2],
    /// then clamps the result to that output range.
    /// @return The mapped and clamped value.
    /// @custom:reverts AttemptedToDivideByZero if start1 == stop1.
    function map(
        int64 n,
        int64 start1,
        int64 stop1,
        int64 start2,
        int64 stop2
    ) internal pure returns (int64) {
        int64 value = mul(
            div(sub(n, start1), sub(stop1, start1)),
            add(sub(stop2, start2), start2)
        );

        return
            start2 < stop2
                ? constrain(value, start2, stop2)
                : constrain(value, stop2, start2);
    }

    /// @notice Clamps n to the inclusive range [low, high].
    function constrain(
        int64 n,
        int64 low,
        int64 high
    ) internal pure returns (int64) {
        return max(min(n, high), low);
    }
}
