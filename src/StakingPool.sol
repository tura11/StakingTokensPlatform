// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// @author  Tura11
// @notice  T11 is a proprietary ERC20 token used as the reward asset in this protocol.

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  StakingPool
/// @author Tura11
/// @notice A staking pool that allows users to stake any ERC20 token and earn T11(Tura11) rewards.
///         T11(Tura11) is a proprietary ERC20 token — it is the sole reward asset distributed by this contract.
/// @dev    Implements the Synthetix staking rewards pattern with a global `rewardPerToken` accumulator.
///
///         ┌─────────────────────────────────────────────────────────────────────────┐
///         │  Architecture overview                                                  │
///         │                                                                         │
///         │  • Users deposit any ERC20 (stakeToken) and earn T11 (rewardToken).    │
///         │  • The owner funds reward periods via notifyRewardAmount().             │
///         │  • Reward accounting  only updated on user action.   │
///         │  • A global accumulator (rewardPerTokenStored) tracks T11 earned per   │
///         │    staked token since inception. Per-user rewards are derived from      │
///         │    the delta between the current accumulator and the user's checkpoint. │
///         └─────────────────────────────────────────────────────────────────────────┘
contract StakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice Thrown when a zero address is supplied where a valid token address is required.
    /// @param  token The zero address that was rejected.
    error StakingPool__AddressZero(address token);

    /// @notice Thrown when `amount` is zero in stake() or withdraw().
    error StakingPool__InvalidAmount();

    /// @notice Thrown when a withdrawal amount exceeds the caller's staked balance.
    error StakingPool__BalanceTooLow();

    /// @notice Reserved error — SafeERC20 reverts directly on transfer failure.
    error StakingPool__TransferFailed();

    /// @notice Revert if duration exceed 30 days;
    error StakingPool__DurationTooLong();

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a user deposits stake tokens into the pool.
    /// @param  user   Address of the staker.
    /// @param  amount Amount of stake tokens deposited.
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws stake tokens from the pool.
    ///         Emitted by both withdraw() and emergencyWithdraw().
    /// @param  user   Address of the withdrawer.
    /// @param  amount Amount of stake tokens returned.
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a user successfully claims their pending T11 rewards.
    ///         Not emitted if the reward balance is zero.
    /// @param  user   Address of the claimant.
    /// @param  amount Amount of T11 tokens transferred.
    event Claimed(address indexed user, uint256 amount);

    /// @notice Emitted when the owner funds a new reward period.
    /// @param  reward   Total T11 tokens added to the pool.
    /// @param  duration Length of the new reward period in seconds.
    event RewardAdded(uint256 reward, uint256 duration);

    // =========================================================================
    // State variables
    // =========================================================================

    /// @notice ERC20 token that users deposit to participate in the pool.
    IERC20 s_StakeToken;

    /// @notice T11 — the proprietary ERC20 token distributed as staking rewards.
    IERC20 s_RewardToken;

    /// @notice Sum of all currently staked token balances across all users.
    uint256 public s_totalSupply;

    /// @notice Cumulative amount of T11 deposited via notifyRewardAmount() since deployment.
    uint256 public s_rewardPool;

    /// @notice T11 tokens emitted per second, distributed proportionally across all stakers.
    /// @dev    Recomputed on every notifyRewardAmount() call. Truncated integer division
    ///         means up to (duration - 1) wei of T11 may remain undistributed after a period ends.
    uint256 public s_rewardRate;

    /// @notice Global accumulator — total T11 earned per staked token since inception, scaled by 1e18.
    /// @dev    Monotonically increasing. Snapshotted by the updateReward modifier before any
    ///         balance-changing operation to preserve reward integrity.
    uint256 public s_rewardPerTokenStored;

    /// @notice Timestamp of the last time the global accumulator was updated.
    /// @dev    Always ≤ s_periodFinish. Set to block.timestamp on every updateReward call.
    uint256 public s_lastUpdateTime;

    /// @notice Timestamp at which the current reward period ends.
    /// @dev    Set to block.timestamp + duration by notifyRewardAmount().
    ///         lastTimeRewardApplicable() caps block.timestamp at this value so reward math
    ///         never counts time beyond the funded period.
    uint256 public s_periodFinish;

    /// @notice Staked token balance per user.
    mapping(address => uint256) public s_balances;

    /// @notice Per-user snapshot of rewardPerTokenStored at the time of their last interaction.
    /// @dev    Used as the baseline in earned() — the user only earns rewards accumulated
    ///         after this checkpoint, preventing retroactive earnings.
    mapping(address => uint256) public s_userRewardPerTokenPaid;

    /// @notice Snapshotted unclaimed T11 rewards per user.
    /// @dev    Written by updateReward on every interaction. Zeroed and transferred in claimReward().
    ///         NOTE: call earned() for the live (unsnapshotted) value.
    mapping(address => uint256) public s_rewards;

    // =========================================================================
    // Modifier
    // =========================================================================

    /// @notice Snapshots the global reward accumulator and the specified user's pending rewards
    ///         before executing the decorated function.
    /// @dev    Must be applied to every function that reads or writes staking/reward state.
    ///
    ///         Passing address(0) skips the per-user update.
    ///         This is intentional — notifyRewardAmount() uses it to snapshot the
    ///         global accumulator before changing rewardRate, without targeting any user.
    /// @param  account User to snapshot, or address(0) for a global-only update.
    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            s_rewards[account] = earned(account);
            s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        }
        _;
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @notice Deploys a new StakingPool for a given stake/reward token pair.
    /// @dev    The deployer (expected to be a StakingFactory or a multisig) becomes
    ///         the owner via Ownable(msg.sender).
    ///         Both token addresses are validated — zero addresses are rejected immediately
    ///         to prevent silent misconfiguration.
    /// @param  _stakeToken  ERC20 token that users will deposit into the pool.
    /// @param  _rewardToken T11 ERC20 token that will be distributed as rewards.
    constructor(address _stakeToken, address _rewardToken) Ownable(msg.sender) {
        if (_stakeToken == address(0)) revert StakingPool__AddressZero(_stakeToken);
        if (_rewardToken == address(0)) revert StakingPool__AddressZero(_rewardToken);
        s_StakeToken = IERC20(_stakeToken);
        s_RewardToken = IERC20(_rewardToken);
    }

    // =========================================================================
    // Public view functions
    // =========================================================================

    /// @notice Returns the timestamp up to which rewards are currently being distributed.
    /// @dev    Caps block.timestamp at s_periodFinish.
    ///         This prevents the reward accumulator from growing beyond the funded window —
    ///         once the period ends, no additional T11 accrues regardless of elapsed time.
    /// @return The lesser of block.timestamp and s_periodFinish.
    function lastTimeRewardApplicable() public view returns (uint256) {
        if (s_periodFinish < block.timestamp) {
            return s_periodFinish;
        } else {
            return block.timestamp;
        }
    }

    /// @notice Calculates the cumulative T11 reward per staked token up to the current moment.
    /// @dev    This is the core of the Synthetix reward distribution pattern.
    ///         The value is a monotonically increasing accumulator scaled by 1e18.
    ///
    ///
    ///
    ///         Returns s_rewardPerTokenStored unchanged when totalSupply == 0
    ///         to avoid division by zero (no stakers → no reward distribution).
    ///
    ///         Example:
    ///           rewardRate = 10 T11/s, totalSupply = 100 tokens, timeDelta = 60 s
    ///           rewardPerToken += (60 * 10 * 1e18) / 100 = 6e18
    ///           → every staked token has earned 6 T11 over those 60 seconds.
    ///
    /// @return Current reward-per-token accumulator value, scaled by 1e18.
    function rewardPerToken() public view returns (uint256) {
        uint256 timeDelta = lastTimeRewardApplicable() - s_lastUpdateTime;
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        } else {
            return s_rewardPerTokenStored + (timeDelta * s_rewardRate * 1e18 / s_totalSupply);
        }
    }

    /// @notice Returns the total T11 rewards earned but not yet claimed by `account`.
    /// @dev    Combines two sources:
    ///
    ///         1) Newly accumulated rewards since the user's last checkpoint:
    ///            balance * (rewardPerToken_NOW - userRewardPerTokenPaid) / 1e18
    ///            The subtraction ensures the user only earns rewards from the moment
    ///            they entered the pool, not from the beginning of the pool's existence.
    ///
    /// 
    ///
    ///         Example:
    ///           balance = 100, rewardPerToken = 8e18, checkpoint = 6e18, stored = 50
    ///           earned = 100 * (8e18 - 6e18) / 1e18 + 50 = 200 + 50 = 250 T11
    ///
    /// @param  account Address of the staker to query.
    /// @return Total T11 rewards earned and pending claim.
    function earned(address account) public view returns (uint256) {
        return s_balances[account] * (rewardPerToken() - s_userRewardPerTokenPaid[account]) / 1e18 + s_rewards[account];
    }

    // =========================================================================
    // External functions
    // =========================================================================

    /// @notice Stakes `amount` of the stake token into the pool.
    /// @dev    updateReward snapshots the caller's rewards BEFORE incrementing the balance.
    ///         This is critical — without the snapshot, the new deposit would retroactively
    ///         earn rewards from before the user entered, inflating their T11 payout.
    ///
    ///
    /// @param  amount Amount of stake tokens to deposit. Must be greater than zero.
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert StakingPool__InvalidAmount();
        s_balances[msg.sender] += amount;
        s_totalSupply += amount;
        s_StakeToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraws the caller's entire stake and claims all pending T11 rewards atomically.
    /// @dev    Delegates to withdraw(s_balances[msg.sender]) followed by claimReward().
    ///         Reentrancy protection and the reward snapshot are handled inside each
    ///         delegated function — no additional guards are needed here.
    ///
    ///         This is the recommended way to fully exit the pool in a single transaction.
    ///
    function exit() external {
        withdraw(s_balances[msg.sender]);
        claimReward();
    }

    /// @notice Withdraws the caller's entire stake immediately, forfeiting ALL pending T11 rewards.
    /// @dev    Intentionally skips both the nonReentrant modifier and updateReward.
    ///         - s_rewards[msg.sender] is zeroed, permanently losing any accrued but
    ///           unclaimed T11 (including rewards not yet flushed by updateReward).
    ///         - State changes precede the external transfer, so reentrancy is not a concern
    ///           despite the missing modifier.
    ///
    ///         Use ONLY in emergency situations where normal withdraw() is unavailable
    ///         (e.g. a bug in the reward accounting logic causing reverts).
    function emergencyWithdraw() external {
        uint256 balance = s_balances[msg.sender];
        s_balances[msg.sender] = 0;
        s_rewards[msg.sender] = 0;
        s_totalSupply -= balance;
        s_StakeToken.safeTransfer(msg.sender, balance);
        emit Withdrawn(msg.sender, balance);
    }

    /// @notice Drains the entire balance of both the stake token and T11 to the owner address.
    /// @dev    Intended exclusively for critical exploit response or contract migration.
    ///         Calling this function will render all user withdrawals impossible —
    ///         stakers will be unable to recover their deposits until the contract is replaced.
    ///
    ///         Both token balances are transferred in a single call to minimise the
    ///         window between checks and transfers during an exploit scenario.
    ///
    function emergencyWithdrawAll() external onlyOwner {
        uint256 stakeBalance = s_StakeToken.balanceOf(address(this));
        uint256 rewardBalance = s_RewardToken.balanceOf(address(this));
        if (stakeBalance > 0) s_StakeToken.safeTransfer(owner(), stakeBalance);
        if (rewardBalance > 0) s_RewardToken.safeTransfer(owner(), rewardBalance);
    }

    /// @notice Funds the pool with T11 rewards and sets the emission rate for a new period.
    /// @dev    updateReward(address(0)) MUST run before rewardRate is mutated.
    ///         Without this snapshot, any T11 earned between the last user interaction and
    ///         now would be silently lost when the rate changes.
    ///
    ///
    ///         Approval requirement: the owner must approve this contract for at least
    ///         `reward` T11 before calling — tokens are pulled via safeTransferFrom.
    ///
    /// @param  reward   Total amount of T11 tokens to distribute over the period.
    /// @param  duration Length of the reward period in seconds.
    ///
    function notifyRewardAmount(uint256 reward, uint256 duration) external onlyOwner updateReward(address(0)) {
        if(duration > 30 days) { // we set max duration to 30 days for safety
            revert StakingPool__DurationTooLong();
        }
        s_RewardToken.safeTransferFrom(msg.sender, address(this), reward);
        s_rewardPool += reward;
        if (block.timestamp >= s_periodFinish) {
            s_rewardRate = reward / duration;
        } else {
            uint256 remaining = s_periodFinish - block.timestamp;
            uint256 leftover = remaining * s_rewardRate;
            s_rewardRate = (reward + leftover) / duration;
        }
        s_periodFinish = block.timestamp + duration;
        s_lastUpdateTime = block.timestamp;
        emit RewardAdded(reward, duration);
    }

    // =========================================================================
    // Public mutating functions
    // =========================================================================

    /// @notice Withdraws `amount` of stake tokens from the pool.
    /// @dev    updateReward snapshots the caller's rewards BEFORE decrementing the balance.
    ///         This preserves pending T11 on partial withdrawals — without the snapshot,
    ///         the balance reduction would reduce the user's calculated earnings retroactively.
    ///
    ///
    /// @param  amount Amount of stake tokens to withdraw.
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert StakingPool__InvalidAmount();
        if (amount > s_balances[msg.sender]) revert StakingPool__BalanceTooLow();
        s_balances[msg.sender] -= amount;
        s_totalSupply -= amount;
        s_StakeToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claims all pending T11 rewards for the caller.
    /// @dev    updateReward flushes earned() into s_rewards[msg.sender] before this
    ///         function body executes, so `reward` always reflects the fully up-to-date value.
    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        if (reward > 0) {
            s_rewards[msg.sender] = 0;
            s_RewardToken.safeTransfer(msg.sender, reward);
            emit Claimed(msg.sender, reward);
        }
    }

    // =========================================================================
    // Getters
    // =========================================================================

    function getUserBalance(address user) public view returns (uint256) {
        return s_balances[user];
    }


    function getUserReward(address user) public view returns (uint256) {
        return s_rewards[user];
    }


    function getUserRewardPerTokenPaid(address user) public view returns (uint256) {
        return s_userRewardPerTokenPaid[user];
    }

  
    function getRewardPerToken() public view returns (uint256) {
        return rewardPerToken();
    }

 
    function getRewardRate() public view returns (uint256) {
        return s_rewardRate;
    }


    function getTotalSupply() public view returns (uint256) {
        return s_totalSupply;
    }


    function getPeriodFinish() public view returns (uint256) {
        return s_periodFinish;
    }

    function getRewardTokenAddress() public view returns (address) {
        return address(s_RewardToken);
    }

    function getStakeTokenAddress() public view returns (address) {
        return address(s_StakeToken);
    }
}