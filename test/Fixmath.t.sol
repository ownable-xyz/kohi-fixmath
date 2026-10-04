// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Fix64.sol";
import "../src/Trig256.sol";

/// The Solidity port must reproduce the outputs of the TS oracle bit for bit. It
/// uses the same corpus as the Rust and TS checks. The golden vectors are
/// int256[] arrays, encoded with abi.encode, in test/golden/abi. Run
/// `npm run goldens` first.
contract FixmathTest is Test {
    function _bin(string memory name)
        internal
        view
        returns (int256[] memory x, int256[] memory y, int256[] memory o)
    {
        bytes memory data = vm.parseBytes(vm.readFile(string.concat("test/golden/abi/", name, ".hex")));
        (x, y, o) = abi.decode(data, (int256[], int256[], int256[]));
    }

    function _un(string memory name) internal view returns (int256[] memory x, int256[] memory o) {
        bytes memory data = vm.parseBytes(vm.readFile(string.concat("test/golden/abi/", name, ".hex")));
        (x, o) = abi.decode(data, (int256[], int256[]));
    }

    function test_Fix64_add() public {
        (int256[] memory x, int256[] memory y, int256[] memory o) = _bin("add");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.add(int64(x[i]), int64(y[i]))), o[i]);
    }

    function test_Fix64_sub() public {
        (int256[] memory x, int256[] memory y, int256[] memory o) = _bin("sub");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.sub(int64(x[i]), int64(y[i]))), o[i]);
    }

    function test_Fix64_mul() public {
        (int256[] memory x, int256[] memory y, int256[] memory o) = _bin("mul");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.mul(int64(x[i]), int64(y[i]))), o[i]);
    }

    function test_Fix64_div() public {
        (int256[] memory x, int256[] memory y, int256[] memory o) = _bin("div");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.div(int64(x[i]), int64(y[i]))), o[i]);
    }

    function test_Fix64_abs() public {
        (int256[] memory x, int256[] memory o) = _un("abs");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.abs(int64(x[i]))), o[i]);
    }

    function test_Fix64_sign() public {
        (int256[] memory x, int256[] memory o) = _un("sign");
        for (uint256 i; i < o.length; i++) assertEq(int256(Fix64.sign(int64(x[i]))), o[i]);
    }

    function test_Trig256_sin() public {
        (int256[] memory x, int256[] memory o) = _un("sin");
        for (uint256 i; i < o.length; i++) assertEq(int256(Trig256.sin(int64(x[i]))), o[i]);
    }

    function test_Trig256_cos() public {
        (int256[] memory x, int256[] memory o) = _un("cos");
        for (uint256 i; i < o.length; i++) assertEq(int256(Trig256.cos(int64(x[i]))), o[i]);
    }

    function test_Trig256_exp() public {
        (int256[] memory x, int256[] memory o) = _un("exp");
        for (uint256 i; i < o.length; i++) assertEq(int256(Trig256.exp(int64(x[i]))), o[i]);
    }

    function test_Trig256_log_256() public {
        (int256[] memory x, int256[] memory o) = _un("log_256");
        for (uint256 i; i < o.length; i++) assertEq(Trig256.log_256(x[i]), o[i]);
    }

    function test_Trig256_log2_256() public {
        (int256[] memory x, int256[] memory o) = _un("log2_256");
        for (uint256 i; i < o.length; i++) assertEq(Trig256.log2_256(x[i]), o[i]);
    }
}
