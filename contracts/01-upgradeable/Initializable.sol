// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Cryft Labs (this adaptation).
// Adapted from cryft-labs/dakota-network/Contracts/Genesis/Upgradeable/Initializable.sol @ 05155f70b4e3, MIT, Modifications © 2026 Cryft Labs.
// Portions derived from OpenZeppelin Contracts Upgradeable v4.9.6 (contracts/proxy/utils/Initializable.sol), MIT, © 2016-2023 zOS Global Limited and contributors.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

/// @title Initializable
/// @notice An implementation behind a proxy has no constructor that runs for the proxy, so its set-up is a function that
///         may run once (`initializer`) and, for later versions, once per version (`reinitializer(n)`).
/// @dev The version lives in a fixed, namespaced slot, so no version's storage layout can collide with it.
///      SAFETY: an implementation calls `_disableInitializers()` in its constructor, so nobody can initialize the
///      implementation contract itself and take it over.
abstract contract Initializable {
    /// @dev keccak256("cryft.examples.Initializable") - 1
    bytes32 private constant _VERSION_SLOT = 0x4b70c20ac606e6949a98961018571e0a29bd50e27bfffa2dd285402dfc47bb02;
    uint64 private constant _DISABLED = type(uint64).max;

    error AlreadyInitialized();

    event Initialized(uint64 version);

    modifier initializer() {
        _advance(1);
        _;
    }

    /// @notice Run a later version's set-up exactly once, in order: a version can never be repeated or skipped back.
    modifier reinitializer(uint64 version) {
        _advance(version);
        _;
    }

    function _disableInitializers() internal {
        _setVersion(_DISABLED);
        emit Initialized(_DISABLED);
    }

    /// @notice The last version set up (type(uint64).max on a disabled implementation).
    function initializedVersion() public view returns (uint64) {
        return _version();
    }

    function _advance(uint64 version) private {
        // checks: only forward, never the disabled marker
        if (version == 0 || version == _DISABLED || version <= _version()) revert AlreadyInitialized();
        // effects
        _setVersion(version);
        emit Initialized(version);
    }

    function _version() private view returns (uint64 v) {
        bytes32 slot = _VERSION_SLOT;
        assembly ("memory-safe") { v := sload(slot) }
    }

    function _setVersion(uint64 v) private {
        bytes32 slot = _VERSION_SLOT;
        assembly ("memory-safe") { sstore(slot, v) }
    }
}
