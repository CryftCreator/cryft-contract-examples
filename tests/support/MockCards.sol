// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @notice Test stand-ins for Cryft Cards and the card authority, with the same read functions (tests only).
contract MockCryftCards {
    mapping(uint256 => bool) public isMinted;
    mapping(uint256 => bool) public isBurned;
    mapping(uint256 => bool) public isWrittenOff;
    mapping(uint256 => bool) public isCollectible;
    mapping(uint256 => address) public makerOf;

    function set(uint256 id, bool minted, bool burned, bool writtenOff, bool collectible, address maker) external {
        isMinted[id] = minted; isBurned[id] = burned; isWrittenOff[id] = writtenOff; isCollectible[id] = collectible; makerOf[id] = maker;
    }

    function tokenURI(uint256 id) external view returns (string memory) {
        require(isMinted[id] && !isBurned[id], "NonexistentToken");
        return string(abi.encodePacked("ipfs://cards/", _decimal(id), ".json"));
    }

    function tokenOfUniqueId(string calldata) external pure returns (uint256) { return 0; }

    function _decimal(uint256 v) private pure returns (bytes memory out) {
        if (v == 0) return "0";
        uint256 n = v; uint256 len;
        while (n != 0) { len++; n /= 10; }
        out = new bytes(len);
        while (v != 0) { out[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
    }
}

contract MockCardAuthority {
    mapping(uint256 => uint8) public stateOf;
    mapping(uint256 => address) public accountOf;

    function set(uint256 id, uint8 state, address account) external { stateOf[id] = state; accountOf[id] = account; }
}
