// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import "./ITenantAllowancePolicy.sol";

/// @title WalletDailyPolicy
/// @notice Decide, in your own contract, how much of your gas account each of your users may spend: a most per
///         operation and a most per day, by default and per wallet. Attach it to your gas account with
///         `setSponsorPolicy` (dashboard: Gas). The GasSponsor calls `reserve` before paying and `settle` after.
/// @dev Adapted and simplified from the network's TenantAllowancePolicy template (verified on the explorer): no tiers, no
///      membership registry. Amounts are in wei (whole numbers; never floats).
///      SAFETY:
///      - Only the GasSponsor may reserve or settle; every operation id is used once (no replay).
///      - Limits are validated when set: enabled means per-operation > 0 and daily >= per-operation; disabled means zero.
///      - A reservation holds the operation's maximum until it settles, so concurrent operations can't overspend a day.
///      - A settlement can never charge more than was reserved, and counters only move by checked arithmetic.
///      - Exit paths: the owner can pause at once, disable any wallet, or detach the policy from the gas account.
///      - No loops, no native coin, no external calls.
contract WalletDailyPolicy is ITenantAllowancePolicy {
    struct Limit { bool configured; bool enabled; uint256 perOperation; uint256 daily; }
    struct Usage { uint256 day; uint256 spent; uint256 reserved; }
    struct Reservation { address wallet; uint256 maximum; uint256 day; }

    address public immutable override gasSponsor;
    address public immutable override sponsor;
    address public owner;
    address public pendingOwner;
    bool public paused;
    Limit public defaultLimit;
    mapping(address => Limit) public walletLimits;
    mapping(address => Usage) private _usage;
    mapping(bytes32 => Reservation) private _reservations;
    mapping(bytes32 => bool) public consumed;
    uint256 public pendingReservations;

    error Unauthorized();
    error InvalidConfiguration();
    error AllowanceUnavailable();
    error OperationAlreadyUsed();
    error InvalidSettlement();

    event OwnershipProposed(address indexed owner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed owner);
    event PolicyPaused(bool paused);
    event DefaultLimitSet(bool enabled, uint256 perOperation, uint256 daily);
    event WalletLimitSet(address indexed wallet, bool configured, bool enabled, uint256 perOperation, uint256 daily);
    event AllowanceReserved(bytes32 indexed operationId, address indexed wallet, uint256 maximumCost, uint256 day);
    event AllowanceCharged(bytes32 indexed operationId, address indexed wallet, uint256 cost, uint256 day);

    /// @param sponsorContract the network's GasSponsor
    /// @param gasAccount your account's id inside it (the dashboard's "Your account in it")
    constructor(address sponsorContract, address gasAccount, address owner_, uint256 perOperation, uint256 daily) {
        if (sponsorContract.code.length == 0 || gasAccount == address(0) || owner_ == address(0)) revert InvalidConfiguration();
        gasSponsor = sponsorContract;
        sponsor = gasAccount;
        owner = owner_;
        defaultLimit = _limit(true, perOperation != 0 || daily != 0, perOperation, daily);
        emit DefaultLimitSet(defaultLimit.enabled, perOperation, daily);
        emit OwnershipTransferred(address(0), owner_);
    }

    modifier onlyOwner() { if (msg.sender != owner) revert Unauthorized(); _; }
    modifier onlySponsor() { if (msg.sender != gasSponsor) revert Unauthorized(); _; }

    // ── the owner's controls ──

    function setPaused(bool value) external onlyOwner { paused = value; emit PolicyPaused(value); }

    function setDefaultLimit(bool enabled, uint256 perOperation, uint256 daily) external onlyOwner {
        defaultLimit = _limit(true, enabled, perOperation, daily);
        emit DefaultLimitSet(enabled, perOperation, daily);
    }

    /// @notice A wallet's own limit. A disabled override stops that wallet even when the default allows it; removing
    ///         the override (configured = false) restores the default. Usage is never reset by either.
    function setWalletLimit(address wallet, bool configured, bool enabled, uint256 perOperation, uint256 daily) external onlyOwner {
        if (wallet == address(0)) revert InvalidConfiguration();
        walletLimits[wallet] = _limit(configured, enabled, perOperation, daily);
        emit WalletLimitSet(wallet, configured, enabled, perOperation, daily);
    }

    function proposeOwner(address next) external onlyOwner {
        if (next == address(0) || next == owner) revert InvalidConfiguration();
        pendingOwner = next;
        emit OwnershipProposed(owner, next);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert Unauthorized();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    // ── what anyone can read ──

    function allowance(address wallet) external view returns (bool enabled, uint256 perOperation, uint256 daily, uint256 available) {
        Limit memory limit = _resolve(wallet);
        enabled = limit.configured && limit.enabled && !paused;
        perOperation = limit.perOperation;
        daily = limit.daily;
        available = enabled ? _remaining(_usage[wallet], daily) : 0;
    }

    // ── the GasSponsor's hooks ──

    function reserve(bytes32 operationId, address wallet, uint256 maximumCost) external override onlySponsor returns (bytes4) {
        if (consumed[operationId] || _reservations[operationId].wallet != address(0)) revert OperationAlreadyUsed();
        if (operationId == bytes32(0) || wallet == address(0) || maximumCost == 0 || paused) revert AllowanceUnavailable();
        Limit memory limit = _resolve(wallet);
        if (!limit.configured || !limit.enabled || maximumCost > limit.perOperation) revert AllowanceUnavailable();
        uint256 day = block.timestamp / 1 days;
        Usage storage usage = _usage[wallet];
        if (usage.day != day) { usage.day = day; usage.spent = 0; }
        if (usage.spent > limit.daily || usage.reserved > limit.daily - usage.spent
            || maximumCost > limit.daily - usage.spent - usage.reserved) revert AllowanceUnavailable();
        usage.reserved += maximumCost;
        _reservations[operationId] = Reservation(wallet, maximumCost, day);
        pendingReservations += 1;
        emit AllowanceReserved(operationId, wallet, maximumCost, day);
        return this.reserve.selector;
    }

    function settle(bytes32 operationId, uint256 chargedCost) external override onlySponsor returns (bytes4) {
        Reservation memory r = _reservations[operationId];
        if (r.wallet == address(0) || chargedCost > r.maximum) revert InvalidSettlement();
        consumed[operationId] = true;
        delete _reservations[operationId];
        pendingReservations -= 1;
        Usage storage usage = _usage[r.wallet];
        uint256 day = block.timestamp / 1 days;
        // A reservation made yesterday is released from yesterday's counters' reserved part; its charge counts today.
        usage.reserved -= r.maximum;
        if (usage.day != day) { usage.day = day; usage.spent = 0; }
        usage.spent += chargedCost;
        emit AllowanceCharged(operationId, r.wallet, chargedCost, day);
        return this.settle.selector;
    }

    function _resolve(address wallet) private view returns (Limit memory limit) {
        limit = walletLimits[wallet];
        if (!limit.configured) limit = defaultLimit;
    }

    function _remaining(Usage storage usage, uint256 daily) private view returns (uint256) {
        uint256 used = (usage.day == block.timestamp / 1 days ? usage.spent : 0) + usage.reserved;
        return used >= daily ? 0 : daily - used;
    }

    function _limit(bool configured, bool enabled, uint256 perOperation, uint256 daily) private pure returns (Limit memory) {
        if ((!configured && (enabled || perOperation != 0 || daily != 0))
            || (enabled && (perOperation == 0 || daily < perOperation))
            || (!enabled && (perOperation != 0 || daily != 0))) revert InvalidConfiguration();
        return Limit(configured, enabled, perOperation, daily);
    }
}
