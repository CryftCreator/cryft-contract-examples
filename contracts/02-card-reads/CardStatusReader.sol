// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs. Written for these examples.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

import "./ICryftCardsRead.sol";

/// @title CardStatusReader
/// @notice Read a Cryft card's public status in one call, and gate something in your own contract on it: for example,
///         "only for cards that are opened and not retired".
/// @dev Read-only: it holds nothing, changes nothing, and can't be paused or broken by its deployer.
///      SAFETY:
///      - Both addresses are checked at deployment and fixed (immutable): nobody can point this reader elsewhere later.
///      - Every external read is a `view` call; a call that reverts (for example tokenURI of a burned card) is never made
///        when the earlier reads already say the card isn't live.
///      - Batches are bounded (BATCH_MOST) so a read can't run out of gas on an unbounded list.
contract CardStatusReader {
    uint8 public constant STATE_NONE = 0;
    uint8 public constant STATE_UNENROLLED = 1;
    uint8 public constant STATE_SET_UP = 2;
    uint8 public constant STATE_ENROLLED = 3;       // opened
    uint8 public constant STATE_RETIRED = 4;
    uint256 public constant BATCH_MOST = 50;

    ICryftCardsRead public immutable cards;
    ICardAuthorityRead public immutable authority;

    struct Status {
        bool minted;
        bool burned;
        bool writtenOff;
        bool collectible;
        uint8 state;
        address maker;
        address account;
    }

    error InvalidConfiguration();
    error BatchTooLarge();
    error NotALiveCard(uint256 cardId);

    constructor(address cards_, address authority_) {
        if (cards_.code.length == 0 || authority_.code.length == 0 || cards_ == authority_) revert InvalidConfiguration();
        cards = ICryftCardsRead(cards_);
        authority = ICardAuthorityRead(authority_);
    }

    function statusOf(uint256 cardId) public view returns (Status memory s) {
        s.minted = cards.isMinted(cardId);
        s.burned = cards.isBurned(cardId);
        s.writtenOff = cards.isWrittenOff(cardId);
        s.collectible = cards.isCollectible(cardId);
        s.maker = cards.makerOf(cardId);
        s.state = authority.stateOf(cardId);
        if (s.state > STATE_RETIRED) s.state = STATE_NONE;   // an unknown value is treated as "no card", never as opened
        s.account = s.state == STATE_ENROLLED ? authority.accountOf(cardId) : address(0);
    }

    /// @notice True for a card that is minted, opened, and not burned, written off or retired.
    function isLiveOpenedCard(uint256 cardId) public view returns (bool) {
        Status memory s = statusOf(cardId);
        return s.minted && !s.burned && !s.writtenOff && s.state == STATE_ENROLLED;
    }

    /// @notice Revert unless the card is live and opened: use it to gate your own functions.
    function requireLiveOpenedCard(uint256 cardId) external view returns (address account) {
        if (!isLiveOpenedCard(cardId)) revert NotALiveCard(cardId);
        return authority.accountOf(cardId);
    }

    /// @notice The status of up to BATCH_MOST cards.
    function statusOfBatch(uint256[] calldata cardIds) external view returns (Status[] memory out) {
        if (cardIds.length > BATCH_MOST) revert BatchTooLarge();
        out = new Status[](cardIds.length);
        for (uint256 i = 0; i < cardIds.length; i++) out[i] = statusOf(cardIds[i]);
    }

    /// @notice The card's metadata URI, or "" when the card isn't minted or is burned (never reverts for those).
    function metadataOf(uint256 cardId) external view returns (string memory) {
        if (!cards.isMinted(cardId) || cards.isBurned(cardId)) return "";
        return cards.tokenURI(cardId);
    }
}
