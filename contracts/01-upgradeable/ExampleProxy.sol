// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @title ExampleProxy
/// @notice An ERC-1967 proxy: the address your users and other contracts know never changes; an upgrade replaces only
///         the logic behind it. This is the pattern Cryft uses so that public addresses stay the same across upgrades.
/// @dev Adapted from the proxy Cryft runs in front of its card vault: an ERC-1967 slot, a delegatecall, and nothing else.
///      SAFETY:
///      - The admin, and only the admin, may upgrade. Make the admin a timelock (ExampleTimelock), never a plain wallet,
///        so every upgrade is announced and waits before it can happen.
///      - Initialization is atomic: the proxy refuses to exist without its initializer call, so nobody can front-run
///        the set-up of a half-made proxy.
///      - No receive(): plain transfers of the native coin revert instead of being stranded in a contract that may not
///        have a way to send them back.
contract ExampleProxy {
    /// @dev bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    /// @dev bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    error NotTheAdmin();
    error InvalidConfiguration();

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor(address implementation_, address admin_, bytes memory initializer) {
        if (implementation_.code.length == 0 || admin_.code.length == 0 || initializer.length == 0) revert InvalidConfiguration();
        _setSlot(_IMPLEMENTATION_SLOT, implementation_);
        _setSlot(_ADMIN_SLOT, admin_);
        emit Upgraded(implementation_);
        emit AdminChanged(address(0), admin_);
        _delegate(implementation_, initializer);
    }

    /// @notice Replace the logic (the address stays). Optionally run the new version's set-up in the same call.
    function upgradeToAndCall(address implementation_, bytes calldata data) external payable {
        if (msg.sender != _slot(_ADMIN_SLOT)) revert NotTheAdmin();
        if (implementation_.code.length == 0) revert InvalidConfiguration();
        _setSlot(_IMPLEMENTATION_SLOT, implementation_);
        emit Upgraded(implementation_);
        if (data.length != 0) _delegate(implementation_, data);
    }

    /// @notice Who may upgrade. Public on purpose: anyone relying on this contract should be able to see it.
    function proxyAdmin() external view returns (address) {
        return _slot(_ADMIN_SLOT);
    }

    /// @notice The logic this proxy runs now. Pin this (not the proxy's own code, which never changes) to notice upgrades.
    function implementation() external view returns (address) {
        return _slot(_IMPLEMENTATION_SLOT);
    }

    fallback() external payable {
        address target = _slot(_IMPLEMENTATION_SLOT);
        assembly ("memory-safe") {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _delegate(address target, bytes memory data) private {
        (bool ok, bytes memory out) = target.delegatecall(data);
        if (!ok) {
            assembly ("memory-safe") { revert(add(out, 0x20), mload(out)) }
        }
    }

    function _slot(bytes32 slot) private view returns (address value) {
        assembly ("memory-safe") { value := sload(slot) }
    }

    function _setSlot(bytes32 slot, address value) private {
        assembly ("memory-safe") { sstore(slot, value) }
    }
}
