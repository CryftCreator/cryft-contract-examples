// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

interface IExampleProxy {
    function upgradeToAndCall(address implementation, bytes calldata data) external payable;
}

/// @title ExampleTimelock
/// @notice The proxy's admin: every upgrade is announced, then waits `delay` before it can run.
/// @dev Adapted from the timelock Cryft uses as the admin of its upgradeable vault.
///      SAFETY:
///      - A timelock does not stop a stolen key. It turns an instant, silent upgrade into a scheduled, public one, with
///        an event the moment it is scheduled and `delay` on the clock for anyone watching to react.
///      - `delay` is immutable and at least one day: the one thing an attacker with the owner key cannot do is shorten it.
///      - Ownership moves in two steps (propose, then accept), so a typo can't hand it to an address nobody holds.
///      - Exit path: `cancel` clears any scheduled upgrade; handing ownership to a contract that can do nothing (or to a
///        multisig) locks upgrades for good when you are ready.
contract ExampleTimelock {
    error NotTheOwner();
    error NothingScheduled();
    error AlreadyScheduled();
    error TooEarly(uint64 readyAt);
    error InvalidConfiguration();

    uint64 public constant DELAY_LEAST = 1 days;
    uint64 public constant DELAY_MOST = 30 days;
    uint256 public constant DATA_MOST = 4096;          // bounds what a scheduled set-up call may carry

    uint64 public immutable delay;
    address public owner;
    address public pendingOwner;
    address public proxy;
    address public scheduledImplementation;
    bytes public scheduledData;
    uint64 public readyAt;

    event ProxyAdopted(address indexed proxy);
    event UpgradeScheduled(address indexed proxy, address indexed implementation, uint64 readyAt);
    event UpgradeCancelled(address indexed proxy, address indexed implementation);
    event UpgradeExecuted(address indexed proxy, address indexed implementation);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address owner_, uint64 delay_) {
        if (owner_ == address(0) || delay_ < DELAY_LEAST || delay_ > DELAY_MOST) revert InvalidConfiguration();
        owner = owner_;
        delay = delay_;
        emit OwnershipTransferred(address(0), owner_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotTheOwner();
        _;
    }

    /// @notice Name the proxy this timelock administers: once, right after the proxy is made.
    function adopt(address proxy_) external onlyOwner {
        if (proxy != address(0) || proxy_.code.length == 0) revert InvalidConfiguration();
        proxy = proxy_;
        emit ProxyAdopted(proxy_);
    }

    function schedule(address implementation, bytes calldata data) external onlyOwner {
        if (proxy == address(0) || implementation.code.length == 0 || data.length > DATA_MOST) revert InvalidConfiguration();
        if (readyAt != 0) revert AlreadyScheduled();
        scheduledImplementation = implementation;
        scheduledData = data;
        readyAt = uint64(block.timestamp) + delay;
        emit UpgradeScheduled(proxy, implementation, readyAt);
    }

    function cancel() external onlyOwner {
        if (readyAt == 0) revert NothingScheduled();
        emit UpgradeCancelled(proxy, scheduledImplementation);
        _clear();
    }

    /// @notice Run the scheduled upgrade once its delay has passed.
    function execute() external onlyOwner {
        // checks
        if (readyAt == 0) revert NothingScheduled();
        if (block.timestamp < readyAt) revert TooEarly(readyAt);
        // effects: clear the schedule before the external call (checks-effects-interactions)
        address implementation = scheduledImplementation;
        bytes memory data = scheduledData;
        _clear();
        // interactions
        IExampleProxy(proxy).upgradeToAndCall(implementation, data);
        emit UpgradeExecuted(proxy, implementation);
    }

    function transferOwnership(address next) external onlyOwner {
        if (next == owner) revert InvalidConfiguration();
        pendingOwner = next;
        emit OwnershipTransferStarted(owner, next);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner || msg.sender == address(0)) revert NotTheOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function _clear() private {
        scheduledImplementation = address(0);
        delete scheduledData;
        readyAt = 0;
    }
}
