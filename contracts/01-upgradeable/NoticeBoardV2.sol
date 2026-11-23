// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs. Written for these examples.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

import "./NoticeBoardV1.sol";

/// @title NoticeBoardV2
/// @notice The upgrade: authors may now take their notice down, and the owner may hide one. Same address, same data.
/// @dev SAFETY: inherits V1 so its storage layout is unchanged; new state is appended after all of V1's (its gap
///      included), never inserted between. tests/test_upgradeable.py checks the layout against V1's.
///      `initializeV2` is a reinitializer: it can run once, and only after V1's set-up.
contract NoticeBoardV2 is NoticeBoardV1 {
    mapping(address => bool) public hidden;         // appended: a record of notices the owner hid

    event NoticeRemoved(address indexed author, address indexed by);

    function initializeV2() external reinitializer(2) {}

    function version() external pure override returns (string memory) {
        return "notice-board-2";
    }

    /// @notice An exit path for every author: take your own notice down.
    function remove() external {
        _remove(msg.sender);
    }

    /// @notice The owner may hide a notice (for example, abuse). The author can always post again.
    function hide(address author) external {
        if (msg.sender != owner) revert NotTheOwner();
        hidden[author] = true;
        _remove(author);
    }

    function _remove(address author) private {
        if (bytes(_notice[author]).length == 0) return;
        delete _notice[author];
        notices -= 1;
        emit NoticeRemoved(author, msg.sender);
    }
}
