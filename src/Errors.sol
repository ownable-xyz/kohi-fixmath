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

/// @notice Custom errors shared by the Fix64 / Trig256 fixed-point library.

/// @notice An index or argument fell outside the range a function accepts.
error ArgumentOutOfRange();

/// @notice A division was attempted with a zero divisor.
error AttemptedToDivideByZero();

/// @notice A function that requires a non-negative input received a negative one.
error NegativeValuePassed();
