// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs. Written for these examples.
// Follows ethereum/ERCs/ERCS/erc-1155.md, CC0-1.0 (a standard; no copyright claimed).
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

/// @notice Test stand-ins: a contract that accepts ERC-1155 items, and one that refuses them (tests only).
contract AcceptingReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) { return this.onERC1155Received.selector; }
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) { return this.onERC1155BatchReceived.selector; }
}

contract RefusingReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) { return 0xdeadbeef; }
}

/// @notice Stands in for the network's GasSponsor so the policy's hooks can be called in tests.
contract FakeGasSponsor {
    function call(address target, bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory out) = target.call(data);
        if (!ok) { assembly ("memory-safe") { revert(add(out, 0x20), mload(out)) } }
        return out;
    }
}
