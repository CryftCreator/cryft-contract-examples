// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @notice The hook the Cryft Network's GasSponsor (0x…FEeD) calls on a developer's policy before and after each
///         operation it pays for from that developer's gas account. A policy never receives the native coin.
///         (The same interface as the network's own, Contracts/Genesis/7702/Interfaces/ITenantAllowancePolicy.sol.)
interface ITenantAllowancePolicy {
    function gasSponsor() external view returns (address);
    function sponsor() external view returns (address);
    function reserve(bytes32 operationId, address wallet, uint256 maximumCost) external returns (bytes4);
    function settle(bytes32 operationId, uint256 chargedCost) external returns (bytes4);
}
