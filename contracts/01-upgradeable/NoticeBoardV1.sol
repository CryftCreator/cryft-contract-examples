// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import "./Initializable.sol";

/// @title NoticeBoardV1
/// @notice The logic behind ExampleProxy: each wallet may keep one short notice. Small on purpose; the point is the
///         upgrade path around it.
/// @dev SAFETY:
///      - Every input is bounded: a notice is 1 to NOTICE_MOST bytes.
///      - No loops over user data, no native coin held, nothing that can get stuck.
///      - Storage is append-only across versions: V2 adds after V1's variables and never reorders or removes them,
///        and `__gap` keeps room for later versions.
contract NoticeBoardV1 is Initializable {
    uint256 public constant NOTICE_MOST = 280;

    address public owner;
    address public pendingOwner;
    uint256 public notices;                         // how many wallets have a notice now
    mapping(address => string) internal _notice;
    uint256[46] private __gap;                      // room for later versions (append only)

    error NotTheOwner();
    error InvalidNotice();
    error InvalidConfiguration();

    event NoticePosted(address indexed author, string text);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();                     // nobody can set up (and so own) the implementation itself
    }

    function initialize(address owner_) external initializer {
        if (owner_ == address(0)) revert InvalidConfiguration();
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    function version() external pure virtual returns (string memory) {
        return "notice-board-1";
    }

    function post(string calldata text) external {
        uint256 length = bytes(text).length;
        if (length == 0 || length > NOTICE_MOST) revert InvalidNotice();
        if (bytes(_notice[msg.sender]).length == 0) notices += 1;
        _notice[msg.sender] = text;
        emit NoticePosted(msg.sender, text);
    }

    function noticeOf(address author) external view returns (string memory) {
        return _notice[author];
    }

    function transferOwnership(address next) external {
        if (msg.sender != owner) revert NotTheOwner();
        pendingOwner = next;
        emit OwnershipTransferStarted(owner, next);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner || msg.sender == address(0)) revert NotTheOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }
}
