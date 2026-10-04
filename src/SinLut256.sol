// SPDX-License-Identifier: MIT
/* Copyright (c) wattsy. Portions Copyright (c) Kohi Art Community, Inc. (MIT). */

/*
 * This is a generated Solidity artifact of Kohi's MIT SinLut256: a 256-entry
 * Q31.32 sine table over [0, PI/2]. The table values are Kohi's MIT-licensed
 * work; this generated file is released under MIT, retaining the original Kohi
 * MIT notice as MIT requires.
 */

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
 * Generated: do not hand-edit. Value-identical to the original Kohi
 * SinLut256 table (256-entry Q31.32 sine LUT over [0, PI/2]), repacked
 * 4 entries per uint256 word so it inlines compactly. Boundary behavior
 * matches the original table's fallthrough: a negative index reads entry 1,
 * an index above 255 reads entry 255.
 */
library SinLut256 {
    /**
     * @notice Lookup table for computing the sine value for a given angle.
     * @param i The clamped and rounded angle integral to index into the table.
     * @return The sine value in fixed-point (Q31.32) space.
     */
    function sinlut(int256 i) internal pure returns (int64) {
        unchecked {
            if (i < 0) i = 1; // original tree fallthrough for negatives
            if (i > 255) i = 255; // and for overflow
            uint256 w = uint256(i) >> 2;
            uint256 lane = uint256(i) & 3;
            return int64(uint64(_word(w) >> ((3 - lane) << 6)));
        }
    }

    function _word(uint256 w) private pure returns (uint256) {
        if (w <= 31) {
            if (w <= 15) {
                if (w <= 7) {
                    if (w <= 3) {
                        if (w <= 1) {
                            if (w <= 0) {
                                return 0x0000000000000000000000000193b2c100000000032761960000000004bb0894;
                            } else {
                                return 0x00000000064ea3ce0000000007e22f59000000000975a749000000000b0907b3;
                            }
                        } else {
                            if (w <= 2) {
                                return 0x000000000c9c4cab000000000e2f7248000000000fc2749e0000000011554fc3;
                            } else {
                                return 0x0000000012e7ffce00000000147a80d400000000160cceee00000000179ee632;
                            }
                        }
                    } else {
                        if (w <= 5) {
                            if (w <= 4) {
                                return 0x000000001930c2b9000000001ac2609b000000001c53bbf1000000001de4d0d7;
                            } else {
                                return 0x000000001f759b6500000000210617b800000000229641eb000000002426161c;
                            }
                        } else {
                            if (w <= 6) {
                                return 0x0000000025b59067000000002744aced0000000028d367cb000000002a61bd23;
                            } else {
                                return 0x000000002befa917000000002d7d27c7000000002f0a3559000000003096cdf1;
                            }
                        }
                    }
                } else {
                    if (w <= 11) {
                        if (w <= 9) {
                            if (w <= 8) {
                                return 0x000000003222edb30000000033ae90c8000000003539b3580000000036c4518b;
                            } else {
                                return 0x00000000384e678d0000000039d7f18a000000003b60ebae000000003ce95229;
                            }
                        } else {
                            if (w <= 10) {
                                return 0x000000003e71212a000000003ff854e400000000417ee98a000000004304db50;
                            } else {
                                return 0x00000000448a266d00000000460ec718000000004792b98b000000004915fa02;
                            }
                        }
                    } else {
                        if (w <= 13) {
                            if (w <= 12) {
                                return 0x000000004a9884b9000000004c1a55ef000000004d9b69e5000000004f1bbcdc;
                            } else {
                                return 0x00000000509b4b1a00000000521a10e50000000053980a840000000055153442;
                            }
                        } else {
                            if (w <= 14) {
                                return 0x0000000056918a6b00000000580d094d000000005987ad38000000005b01727f;
                            } else {
                                return 0x000000005c7a5576000000005df25274000000005f6965d20000000060df8bec;
                            }
                        }
                    }
                }
            } else {
                if (w <= 23) {
                    if (w <= 19) {
                        if (w <= 17) {
                            if (w <= 16) {
                                return 0x000000006254c11e0000000063c901ca00000000653c4a500000000066ae9716;
                            } else {
                                return 0x00000000681fe4840000000069902f01000000006aff72fc000000006c6dace2;
                            }
                        } else {
                            if (w <= 18) {
                                return 0x000000006ddad924000000006f46f4370000000070b1fa9200000000721be8ac;
                            } else {
                                return 0x000000007384bb030000000074ec6e15000000007652fe630000000077b86873;
                            }
                        }
                    } else {
                        if (w <= 21) {
                            if (w <= 20) {
                                return 0x00000000791ca8ca000000007a7fbbf4000000007be19e7c000000007d424cf4;
                            } else {
                                return 0x000000007ea1c3ee000000007fffffff00000000815cfdc20000000082b8b9d3;
                            }
                        } else {
                            if (w <= 22) {
                                return 0x00000000841330cf00000000856c5f5b0000000086c4421b00000000881ad5b8;
                            } else {
                                return 0x00000000897016df000000008ac4023e000000008c169489000000008d67ca76;
                            }
                        }
                    }
                } else {
                    if (w <= 27) {
                        if (w <= 25) {
                            if (w <= 24) {
                                return 0x000000008eb7a0bd000000009006141d000000009153215400000000929ec527;
                            } else {
                                return 0x0000000093e8fc5e000000009531c3c200000000967918230000000097bef652;
                            }
                        } else {
                            if (w <= 26) {
                                return 0x0000000099035b26000000009a464376000000009b87ac21000000009cc79207;
                            } else {
                                return 0x000000009e05f20c000000009f42c91a00000000a07e141b00000000a1b7d000;
                            }
                        }
                    } else {
                        if (w <= 29) {
                            if (w <= 28) {
                                return 0x00000000a2eff9bc00000000a4268e4800000000a55b8a9f00000000a68eebc1;
                            } else {
                                return 0x00000000a7c0aeb100000000a8f0d07700000000aa1f4e1e00000000ab4c24b7;
                            }
                        } else {
                            if (w <= 30) {
                                return 0x00000000ac77515400000000ada0d11000000000aec8a10400000000afeebe52;
                            } else {
                                return 0x00000000b113261f00000000b235d59300000000b356c9db00000000b476002a;
                            }
                        }
                    }
                }
            }
        } else {
            if (w <= 47) {
                if (w <= 39) {
                    if (w <= 35) {
                        if (w <= 33) {
                            if (w <= 32) {
                                return 0x00000000b59375b300000000b6af27b300000000b7c9136600000000b8e13611;
                            } else {
                                return 0x00000000b9f78cfb00000000bb0c156e00000000bc1eccbd00000000bd2fb03a;
                            }
                        } else {
                            if (w <= 34) {
                                return 0x00000000be3ebd4100000000bf4bf12f00000000c057496600000000c160c34d;
                            } else {
                                return 0x00000000c2685c5100000000c36e11e200000000c471e17400000000c573c883;
                            }
                        }
                    } else {
                        if (w <= 37) {
                            if (w <= 36) {
                                return 0x00000000c673c48d00000000c771d31400000000c86df1a200000000c9681dc3;
                            } else {
                                return 0x00000000ca60550900000000cb56950b00000000cc4adb6400000000cd3d25b6;
                            }
                        } else {
                            if (w <= 38) {
                                return 0x00000000ce2d71a500000000cf1bbcdc00000000d008050b00000000d0f247e5;
                            } else {
                                return 0x00000000d1da832500000000d2c0b48800000000d3a4d9d300000000d486f0ce;
                            }
                        }
                    }
                } else {
                    if (w <= 43) {
                        if (w <= 41) {
                            if (w <= 40) {
                                return 0x00000000d566f74600000000d644eb0f00000000d720ca0100000000d7fa91f8;
                            } else {
                                return 0x00000000d8d240d800000000d9a7d48800000000da7b4af500000000db4ca210;
                            }
                        } else {
                            if (w <= 42) {
                                return 0x00000000dc1bd7d300000000dce8ea3800000000ddb3d74200000000de7c9cf9;
                            } else {
                                return 0x00000000df43396900000000e007aaa500000000e0c9eec300000000e18a03e1;
                            }
                        }
                    } else {
                        if (w <= 45) {
                            if (w <= 44) {
                                return 0x00000000e247e82100000000e30399ab00000000e3bd16ad00000000e4745d57;
                            } else {
                                return 0x00000000e5296be400000000e5dc409100000000e68cd9a100000000e73b355d;
                            }
                        } else {
                            if (w <= 46) {
                                return 0x00000000e7e7521300000000e8912e1800000000e938c7c400000000e9de1d77;
                            } else {
                                return 0x00000000ea812d9700000000eb21f68d00000000ebc076ca00000000ec5cacc3;
                            }
                        }
                    }
                }
            } else {
                if (w <= 55) {
                    if (w <= 51) {
                        if (w <= 49) {
                            if (w <= 48) {
                                return 0x00000000ecf696f400000000ed8e33df00000000ee23820900000000eeb68001;
                            } else {
                                return 0x00000000ef472c5800000000efd585a700000000f0618a8c00000000f0eb39aa;
                            }
                        } else {
                            if (w <= 50) {
                                return 0x00000000f17291ab00000000f1f7913e00000000f27a371900000000f2fa81f8;
                            } else {
                                return 0x00000000f378709a00000000f3f401c600000000f46d344a00000000f4e406f8;
                            }
                        }
                    } else {
                        if (w <= 53) {
                            if (w <= 52) {
                                return 0x00000000f55878a900000000f5ca883b00000000f63a349100000000f6a77c98;
                            } else {
                                return 0x00000000f7125f3e00000000f77adb7a00000000f7e0f04900000000f8449cac;
                            }
                        } else {
                            if (w <= 54) {
                                return 0x00000000f8a5dfab00000000f904b85500000000f96125bd00000000f9bb26ff;
                            } else {
                                return 0x00000000fa12bb3900000000fa67e19300000000faba993900000000fb0ae15c;
                            }
                        }
                    }
                } else {
                    if (w <= 59) {
                        if (w <= 57) {
                            if (w <= 56) {
                                return 0x00000000fb58b93500000000fba4200300000000fbed150b00000000fc339795;
                            } else {
                                return 0x00000000fc77a6f500000000fcb9427f00000000fcf8699100000000fd351b8e;
                            }
                        } else {
                            if (w <= 58) {
                                return 0x00000000fd6f57df00000000fda71df300000000fddc6d4000000000fe0f4540;
                            } else {
                                return 0x00000000fe3fa57600000000fe6d8d6900000000fe98fca700000000fec1f2c4;
                            }
                        }
                    } else {
                        if (w <= 61) {
                            if (w <= 60) {
                                return 0x00000000fee86f5a00000000ff0c720a00000000ff2dfa7900000000ff4d0855;
                            } else {
                                return 0x00000000ff699b4f00000000ff83b32200000000ff9b4f8d00000000ffb07054;
                            }
                        } else {
                            if (w <= 62) {
                                return 0x00000000ffc3154300000000ffd33e2b00000000ffe0eae500000000ffec1b4f;
                            } else {
                                return 0x00000000fff4cf4c00000000fffb06c700000000fffec1b10000000100000000;
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * @notice sinlut() against a memory-resident copy of the table (entry i
     *         at lutPtr + i*8, big-endian: the table() blob staged verbatim,
     *         with >= 24 bytes of readable slack after it for the tail mload).
     *         Value- and boundary-identical to sinlut(i); costs one mload
     *         instead of the ~2.6 KB selection tree, for callers that need
     *         to stay under a contract size limit such as EIP-170.
     */
    function sinlut(uint256 lutPtr, int256 i) internal pure returns (int64 v) {
        unchecked {
            if (i < 0) i = 1; // original tree fallthrough for negatives
            if (i > 255) i = 255; // and for overflow
            assembly {
                v := shr(192, mload(add(lutPtr, shl(3, i))))
            }
        }
    }

    /// @notice The full table as one blob (entry i at byte i*8, big-endian),
    ///         for staging into an SSTORE2 data contract at deploy time.
    ///         Reference it from constructors only, so the 2 KB rides in
    ///         initcode and never counts against the runtime size limit.
    function table() internal pure returns (bytes memory) {
        return
            hex"0000000000000000000000000193b2c100000000032761960000000004bb089400000000064ea3ce0000000007e22f59000000000975a749000000000b0907b3000000000c9c4cab000000000e2f7248000000000fc2749e0000000011554fc30000000012e7ffce00000000147a80d400000000160cceee00000000179ee632000000001930c2b9000000001ac2609b000000001c53bbf1000000001de4d0d7000000001f759b6500000000210617b800000000229641eb000000002426161c0000000025b59067000000002744aced0000000028d367cb000000002a61bd23000000002befa917000000002d7d27c7000000002f0a3559000000003096cdf1000000003222edb30000000033ae90c8000000003539b3580000000036c4518b00000000384e678d0000000039d7f18a000000003b60ebae000000003ce95229000000003e71212a000000003ff854e400000000417ee98a000000004304db5000000000448a266d00000000460ec718000000004792b98b000000004915fa02000000004a9884b9000000004c1a55ef000000004d9b69e5000000004f1bbcdc00000000509b4b1a00000000521a10e50000000053980a8400000000551534420000000056918a6b00000000580d094d000000005987ad38000000005b01727f000000005c7a5576000000005df25274000000005f6965d20000000060df8bec000000006254c11e0000000063c901ca00000000653c4a500000000066ae971600000000681fe4840000000069902f01000000006aff72fc000000006c6dace2000000006ddad924000000006f46f4370000000070b1fa9200000000721be8ac000000007384bb030000000074ec6e15000000007652fe630000000077b8687300000000791ca8ca000000007a7fbbf4000000007be19e7c000000007d424cf4000000007ea1c3ee000000007fffffff00000000815cfdc20000000082b8b9d300000000841330cf00000000856c5f5b0000000086c4421b00000000881ad5b800000000897016df000000008ac4023e000000008c169489000000008d67ca76000000008eb7a0bd000000009006141d000000009153215400000000929ec5270000000093e8fc5e000000009531c3c200000000967918230000000097bef6520000000099035b26000000009a464376000000009b87ac21000000009cc79207000000009e05f20c000000009f42c91a00000000a07e141b00000000a1b7d00000000000a2eff9bc00000000a4268e4800000000a55b8a9f00000000a68eebc100000000a7c0aeb100000000a8f0d07700000000aa1f4e1e00000000ab4c24b700000000ac77515400000000ada0d11000000000aec8a10400000000afeebe5200000000b113261f00000000b235d59300000000b356c9db00000000b476002a00000000b59375b300000000b6af27b300000000b7c9136600000000b8e1361100000000b9f78cfb00000000bb0c156e00000000bc1eccbd00000000bd2fb03a00000000be3ebd4100000000bf4bf12f00000000c057496600000000c160c34d00000000c2685c5100000000c36e11e200000000c471e17400000000c573c88300000000c673c48d00000000c771d31400000000c86df1a200000000c9681dc300000000ca60550900000000cb56950b00000000cc4adb6400000000cd3d25b600000000ce2d71a500000000cf1bbcdc00000000d008050b00000000d0f247e500000000d1da832500000000d2c0b48800000000d3a4d9d300000000d486f0ce00000000d566f74600000000d644eb0f00000000d720ca0100000000d7fa91f800000000d8d240d800000000d9a7d48800000000da7b4af500000000db4ca21000000000dc1bd7d300000000dce8ea3800000000ddb3d74200000000de7c9cf900000000df43396900000000e007aaa500000000e0c9eec300000000e18a03e100000000e247e82100000000e30399ab00000000e3bd16ad00000000e4745d5700000000e5296be400000000e5dc409100000000e68cd9a100000000e73b355d00000000e7e7521300000000e8912e1800000000e938c7c400000000e9de1d7700000000ea812d9700000000eb21f68d00000000ebc076ca00000000ec5cacc300000000ecf696f400000000ed8e33df00000000ee23820900000000eeb6800100000000ef472c5800000000efd585a700000000f0618a8c00000000f0eb39aa00000000f17291ab00000000f1f7913e00000000f27a371900000000f2fa81f800000000f378709a00000000f3f401c600000000f46d344a00000000f4e406f800000000f55878a900000000f5ca883b00000000f63a349100000000f6a77c9800000000f7125f3e00000000f77adb7a00000000f7e0f04900000000f8449cac00000000f8a5dfab00000000f904b85500000000f96125bd00000000f9bb26ff00000000fa12bb3900000000fa67e19300000000faba993900000000fb0ae15c00000000fb58b93500000000fba4200300000000fbed150b00000000fc33979500000000fc77a6f500000000fcb9427f00000000fcf8699100000000fd351b8e00000000fd6f57df00000000fda71df300000000fddc6d4000000000fe0f454000000000fe3fa57600000000fe6d8d6900000000fe98fca700000000fec1f2c400000000fee86f5a00000000ff0c720a00000000ff2dfa7900000000ff4d085500000000ff699b4f00000000ff83b32200000000ff9b4f8d00000000ffb0705400000000ffc3154300000000ffd33e2b00000000ffe0eae500000000ffec1b4f00000000fff4cf4c00000000fffb06c700000000fffec1b10000000100000000";
    }
}
