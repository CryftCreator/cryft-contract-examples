// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @notice A stand-in for Remix's own "remix_tests.sol" (which Remix provides at run time), so the Remix tests can also be
///         compiled and run by pytest. Same call shape: Assert.ok / equal / notEqual / greaterThan / lesserThan, each
///         emitting AssertionEvent(passed, message, methodName). Internal here (Remix links its own library).
library Assert {
    event AssertionEvent(bool passed, string message, string methodName);

    function ok(bool a, string memory message) internal returns (bool) {
        emit AssertionEvent(a, message, "ok");
        return a;
    }

    function equal(uint256 a, uint256 b, string memory message) internal returns (bool r) {
        r = a == b; emit AssertionEvent(r, message, "equal");
    }

    function equal(address a, address b, string memory message) internal returns (bool r) {
        r = a == b; emit AssertionEvent(r, message, "equal");
    }

    function equal(bool a, bool b, string memory message) internal returns (bool r) {
        r = a == b; emit AssertionEvent(r, message, "equal");
    }

    function equal(string memory a, string memory b, string memory message) internal returns (bool r) {
        r = keccak256(bytes(a)) == keccak256(bytes(b)); emit AssertionEvent(r, message, "equal");
    }

    function notEqual(address a, address b, string memory message) internal returns (bool r) {
        r = a != b; emit AssertionEvent(r, message, "notEqual");
    }

    function greaterThan(uint256 a, uint256 b, string memory message) internal returns (bool r) {
        r = a > b; emit AssertionEvent(r, message, "greaterThan");
    }
}
