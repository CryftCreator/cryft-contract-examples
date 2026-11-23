// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

/// @title SponsoredGuestbook
/// @notice A contract built to be called through developer gas sponsorship: your users sign, your gas account pays,
///         and you list this contract as an allowed target so your account pays for calls to it and nothing else.
/// @dev Nothing in the contract itself knows about sponsorship; what matters is how it is written:
///      - Identity is `msg.sender`, the user's own account (an EIP-7702 account on the Cryft Network), never `tx.origin`,
///        which is the relayer when a call is sponsored.
///      - Every input is bounded (a message is 1..MESSAGE_MOST bytes) and each wallet waits COOLDOWN between entries,
///        so nobody can spend your gas account by flooding it.
///      - It holds no native coin (nothing is payable) and keeps no unbounded list in storage: entries are events, with
///        only a count and each wallet's last time stored.
///      SPONSORSHIP IS "SOON": paying for calls from a developer's gas account (POST /developer/gas/execute, and the
///      GasSponsor's allowed targets) is not open on the card service yet. Deploy and call it with your own wallet today.
contract SponsoredGuestbook {
    uint256 public constant MESSAGE_MOST = 200;
    uint256 public constant COOLDOWN = 1 minutes;

    uint256 public entries;
    mapping(address => uint256) public lastSignedAt;

    error InvalidMessage();
    error TooSoon(uint256 readyAt);

    event Signed(address indexed by, uint256 indexed index, string message);

    function sign(string calldata message) external returns (uint256 index) {
        uint256 length = bytes(message).length;
        if (length == 0 || length > MESSAGE_MOST) revert InvalidMessage();
        uint256 last = lastSignedAt[msg.sender];
        if (last != 0 && block.timestamp < last + COOLDOWN) revert TooSoon(last + COOLDOWN);
        lastSignedAt[msg.sender] = block.timestamp;
        index = ++entries;
        emit Signed(msg.sender, index, message);
    }
}
