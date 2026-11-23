// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Cryft Labs (this adaptation).
// Adapted from GiftablesV2_3 (Cryft Labs), verified source at https://explore.dakota.cards/address/0xF743c2b2Ff6EE304EE678313FdF4a059fa683636, MIT, © 2026 Cryft Labs.
// Portions derived from OpenZeppelin Contracts v4.9.6 (contracts/token/ERC1155/ERC1155.sol), MIT, © 2016-2023 zOS Global Limited and contributors.
// Follows ethereum/ERCs/ERCS/erc-1155.md, CC0-1.0 (a standard; no copyright claimed).
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

import "../01-upgradeable/Initializable.sol";

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

/// @title CollectibleItems
/// @notice ERC-1155 items your app puts inside Cryft Cards, the way Cryft's own Giftables are made: each item is its own
///         token id (one of one), with a `kind` (greeting, postcard, ticket, ...), a privacy flag and its own metadata URI.
///         Mint an item straight into a card's account (CardStatusReader.accountOf), and it travels with the card.
/// @dev Adapted from Cryft's Giftables (v3). Deploy it behind ExampleProxy with an ExampleTimelock as admin (see
///      01-upgradeable) so you can fix it later without changing its address.
///      SAFETY:
///      - NO APPROVALS: only an item's holder moves it (`from` must be msg.sender). There are no operators that could
///        outlive a change of holder and take items later.
///      - Bounded: a batch mints or moves at most MAX_BATCH items; `kind` and `uri` have most lengths.
///      - Only existing items move, and balances use checked arithmetic.
///      - A receiving contract must accept (ERC-1155 receiver check); one refusal reverts the whole batch.
///      - Exit paths: the owner can change the minter or set it to address(0) to stop minting for good; holders can
///        always move their own items.
///      - Privacy: `privateContents` only says the URI is a neutral cover. Never put private words on chain; keep them
///        encrypted off chain for the holder.
contract CollectibleItems is Initializable {
    string public constant name = "Collectible Items";
    string public constant symbol = "ITEM";
    uint256 public constant MAX_BATCH = 100;
    uint256 public constant KIND_MOST = 32;
    uint256 public constant URI_MOST = 256;

    struct Item {
        string kind;
        bool privateContents;
        string uri;
    }

    address public owner;
    address public pendingOwner;
    address public minter;
    uint256 public totalSupply;                     // ids start at 1; every item is one of one
    mapping(uint256 => Item) private _items;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    uint256[44] private __gap;                      // room for later versions (append only)

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event URI(string value, uint256 indexed id);
    event ItemMinted(uint256 indexed id, address indexed to, string kind, bool privateContents);
    event MinterChanged(address indexed minter);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotMinter();
    error NoSuchItem();
    error NotAuthorized();
    error ZeroAddress();
    error Insufficient();
    error LengthMismatch();
    error ReceiverRefused();
    error BatchTooLarge();
    error ApprovalsDisabled();
    error InvalidItem();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyMinter() { if (msg.sender != minter) revert NotMinter(); _; }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address owner_, address minter_) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        minter = minter_;
        emit OwnershipTransferred(address(0), owner_);
        emit MinterChanged(minter_);
    }

    // ── administration ──

    /// @notice address(0) stops minting.
    function setMinter(address minter_) external onlyOwner {
        minter = minter_;
        emit MinterChanged(minter_);
    }

    function transferOwnership(address next) external onlyOwner {
        pendingOwner = next;
        emit OwnershipTransferStarted(owner, next);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner || msg.sender == address(0)) revert NotAuthorized();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    // ── minting ──

    function mint(address to, string calldata kind, bool privateContents, string calldata uri_) external onlyMinter returns (uint256 id) {
        _checkItem(kind, uri_);
        id = _mint(to, kind, privateContents, uri_);
    }

    /// @notice One item into each of `to` (at most MAX_BATCH): the same kind, privacy and metadata for the whole stack.
    ///         Ids are consecutive in the order of `to`; one refusal reverts them all.
    function mintBatch(address[] calldata to, string calldata kind, bool privateContents, string calldata uri_)
        external onlyMinter returns (uint256[] memory ids)
    {
        if (to.length == 0 || to.length > MAX_BATCH) revert BatchTooLarge();
        _checkItem(kind, uri_);
        ids = new uint256[](to.length);
        for (uint256 i = 0; i < to.length; i++) ids[i] = _mint(to[i], kind, privateContents, uri_);
    }

    // ── reading ──

    function exists(uint256 id) public view returns (bool) { return id != 0 && id <= totalSupply; }

    function itemOf(uint256 id) external view returns (string memory kind, bool privateContents, string memory uri_) {
        if (!exists(id)) revert NoSuchItem();
        Item storage item = _items[id];
        return (item.kind, item.privateContents, item.uri);
    }

    function uri(uint256 id) external view returns (string memory) {
        if (!exists(id)) revert NoSuchItem();
        return _items[id].uri;
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory out) {
        if (accounts.length != ids.length) revert LengthMismatch();
        if (ids.length > MAX_BATCH) revert BatchTooLarge();
        out = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) out[i] = balanceOf(accounts[i], ids[i]);
    }

    // ── moving (holders only) ──

    function setApprovalForAll(address, bool) external pure { revert ApprovalsDisabled(); }

    function isApprovedForAll(address, address) external pure returns (bool) { return false; }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external {
        if (msg.sender != from) revert NotAuthorized();
        if (to == address(0)) revert ZeroAddress();
        _move(from, to, id, value);
        emit TransferSingle(msg.sender, from, to, id, value);
        _checkReceiver(msg.sender, from, to, id, value, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external {
        if (msg.sender != from) revert NotAuthorized();
        if (to == address(0)) revert ZeroAddress();
        if (ids.length != values.length) revert LengthMismatch();
        if (ids.length > MAX_BATCH) revert BatchTooLarge();
        for (uint256 i = 0; i < ids.length; i++) _move(from, to, ids[i], values[i]);
        emit TransferBatch(msg.sender, from, to, ids, values);
        if (to.code.length != 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, values, data) returns (bytes4 selector) {
                if (selector != IERC1155Receiver.onERC1155BatchReceived.selector) revert ReceiverRefused();
            } catch {
                revert ReceiverRefused();
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0xd9b67a26 || interfaceId == 0x0e89341c; // ERC-165, ERC-1155, metadata URI
    }

    // ── internals ──

    function _checkItem(string calldata kind, string calldata uri_) private pure {
        uint256 k = bytes(kind).length;
        uint256 u = bytes(uri_).length;
        if (k == 0 || k > KIND_MOST || u == 0 || u > URI_MOST) revert InvalidItem();
    }

    function _mint(address to, string calldata kind, bool privateContents, string calldata uri_) private returns (uint256 id) {
        if (to == address(0)) revert ZeroAddress();
        id = ++totalSupply;
        _items[id] = Item(kind, privateContents, uri_);
        _balances[id][to] = 1;
        emit TransferSingle(msg.sender, address(0), to, id, 1);
        emit URI(uri_, id);
        emit ItemMinted(id, to, kind, privateContents);
        _checkReceiver(msg.sender, address(0), to, id, 1, "");
    }

    function _move(address from, address to, uint256 id, uint256 value) private {
        if (!exists(id)) revert NoSuchItem();
        uint256 held = _balances[id][from];
        if (held < value) revert Insufficient();
        _balances[id][from] = held - value;
        _balances[id][to] += value;
    }

    function _checkReceiver(address operator, address from, address to, uint256 id, uint256 value, bytes memory data) private {
        if (to.code.length == 0) return;
        try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (bytes4 selector) {
            if (selector != IERC1155Receiver.onERC1155Received.selector) revert ReceiverRefused();
        } catch {
            revert ReceiverRefused();
        }
    }
}
