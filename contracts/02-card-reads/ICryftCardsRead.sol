// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs (this adaptation).
// Adapted from CryftCardsV8_2 (Cryft Labs), verified source at https://explore.dakota.cards/address/0xb251095a39Ff74e317657Ce09Ec2fdEd4f479A11, Apache-2.0, © 2023-2026 Cryft Labs.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

/// @notice The read-only part of Cryft Cards (V8.2), the card NFT collection. These functions are on the verified
///         contract on the Cryft Network explorer. Read the live address from GET /v1/platform/tenants/cryft.cards/v8/config
///         (never hard-code it: it is a proxy, so it stays the same across upgrades, but check it once at start-up).
/// @dev A card's NFT is always held by the card vault, so `ownerOf` answers the vault for every minted card. Who holds
///      a card is a credential in the card authority, checked by proof; ask the card service (with the user's session)
///      for "which cards does this user hold".
interface ICryftCardsRead {
    function isMinted(uint256 cardId) external view returns (bool);
    function isBurned(uint256 cardId) external view returns (bool);
    function isWrittenOff(uint256 cardId) external view returns (bool);
    function isCollectible(uint256 cardId) external view returns (bool);
    /// @notice Who made (bought) the card's batch; address(0) for an id never reserved.
    function makerOf(uint256 cardId) external view returns (address);
    /// @notice Reverts for a card not minted, or burned.
    function tokenURI(uint256 cardId) external view returns (string memory);
    /// @notice The card a unique id names; 0 if it names none.
    function tokenOfUniqueId(string calldata uniqueId) external view returns (uint256);
}

/// @notice The read-only part of the card authority (V8.2) used here. Also on its verified contract.
interface ICardAuthorityRead {
    /// @notice 0 NONE, 1 UNENROLLED, 2 SET_UP, 3 ENROLLED (opened: born at its first claim), 4 RETIRED.
    function stateOf(uint256 cardId) external view returns (uint8);
    /// @notice The card's own account (ERC-6551): where its gifts live.
    function accountOf(uint256 cardId) external view returns (address);
}
