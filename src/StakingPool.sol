// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract StakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardAdded(uint256 reward, uint256 duration);

    error StakingPool__AddressZero(address token);
    error StakingPool__InvalidAmount();
    error StakingPool__BalanceTooLow();
    error StakingPool__TransferFailed();

    IERC20 s_StakeToken;
    IERC20 s_RewardToken;


    uint256 public s_totalSupply;
    uint256 public s_rewardPool;
    uint256 public s_rewardRate;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;
    uint256 public s_periodFinish;


    mapping(address => uint256) public s_balances;
    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    modifier updateReward(address account) {
    s_rewardPerTokenStored = rewardPerToken();
    s_lastUpdateTime = lastTimeRewardApplicable();
    if(account != address(0)) {
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
    }
    _;
    }


    constructor(address _stakeToken, address _rewardToken) Ownable(msg.sender) {
        if(_stakeToken == address(0)) {
            revert StakingPool__AddressZero(_stakeToken);
        }
        if(_rewardToken == address(0)) {
            revert StakingPool__AddressZero(_rewardToken);
        }
        s_StakeToken = IERC20(_stakeToken);
        s_RewardToken = IERC20(_rewardToken);
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        if(s_periodFinish < block.timestamp) {
            return s_periodFinish;
        }else {
            return block.timestamp;
        }
    }


    /**
    * @notice Calculates the reward per token accumulated since the last update.
    * @dev This function is the core of the reward distribution mechanism.
    * 
    * The reward per token is a global accumulator that increases over time.
    * Instead of tracking every user's rewards every second (which would be 
    * too expensive), we use this single value to calculate any user's rewards
    * at any point in time.
    * 
    * Formula:
    * rewardPerToken = rewardPerTokenStored + (timeDelta * rewardRate * 1e18 / totalSupply)
    * 
    * Where:
    * - rewardPerTokenStored: previously accumulated value
    * - timeDelta: seconds elapsed since last update (capped at periodFinish)
    * - rewardRate: T11 tokens distributed per second across all stakers
    * - 1e18: precision factor (Solidity has no floating point)
    * - totalSupply: total tokens currently staked
    * 
    * Example:
    * rewardRate = 10 T11/s, totalSupply = 100, timeDelta = 60s
    * rewardPerToken = 0 + (60 * 10 * 1e18 / 100) = 6e18
    * Meaning: every staked token has earned 6 T11 over 60 seconds
    * 
    * @return Current reward per token scaled by 1e18
    */
    function rewardPerToken() public view returns (uint256) {
        uint256 timeDelta = lastTimeRewardApplicable() - s_lastUpdateTime;
        if(s_totalSupply == 0){
            return s_rewardPerTokenStored;
        }else{
            return s_rewardPerTokenStored + (timeDelta * s_rewardRate * 1e18 / s_totalSupply);
        }
    }

    /**
    * @notice Calculates the total amount of T11 rewards earned by an account.
    * @dev Combines two sources of rewards:
    * 
    * 1) Newly accumulated rewards since the last time the user interacted:
    *    balance * (rewardPerToken NOW - rewardPerToken WHEN USER LAST UPDATED)
    *    
    *    The subtraction is crucial — it ensures the user only earns rewards
    *    from the moment they entered the pool, not from the beginning of time.
    *    userRewardPerTokenPaid acts as a "checkpoint" set every time the user
    *    stakes, withdraws, or claims.
    * 
    * 2) Previously accumulated rewards (s_rewards[account]):
    *    Rewards that were calculated during a previous interaction but not
    *    yet claimed. For example, if a user partially withdraws, their earned
    *    rewards are saved to s_rewards before their balance changes.
    * 
    * Example:
    * balance = 100 USDC
    * rewardPerToken() = 8e18
    * userRewardPerTokenPaid = 6e18  (checkpoint when user entered)
    * s_rewards = 0
    * 
    * earned = 100 * (8e18 - 6e18) / 1e18 + 0 = 200 T11
    * Meaning: user earned 200 T11 since they entered the pool
    * 
    * @param account Address of the staker
    * @return Total T11 rewards earned and pending claim
    */
    function earned(address account) public view returns (uint256) {
        return s_balances[account] * (rewardPerToken() - s_userRewardPerTokenPaid[account]) / 1e18 + s_rewards[account];
    }


    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if(amount == 0) {
            revert StakingPool__InvalidAmount();
        }   
        s_balances[msg.sender] += amount;
        s_totalSupply += amount;
        s_StakeToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }


    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if(amount == 0) {
            revert StakingPool__InvalidAmount();
        }
        if(amount > s_balances[msg.sender]) {
            revert StakingPool__BalanceTooLow();
        } 
        s_balances[msg.sender] -= amount;
        s_totalSupply -= amount;
        s_StakeToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }


    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        if(reward > 0){
            s_rewards[msg.sender] = 0;
            s_RewardToken.safeTransfer(msg.sender, reward);
            emit Claimed(msg.sender, reward);
        }  
    }


    function exit() external {
        withdraw(s_balances[msg.sender]);
        claimReward();
    }



    function notifyRewardAmount(uint256 reward, uint256 duration) external onlyOwner updateReward(address(0)) {
        s_RewardToken.safeTransferFrom(msg.sender, address(this), reward);
        s_rewardPool += reward;
        if(block.timestamp >= s_periodFinish) {
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


    function emegrencyWithdraw() external {
        uint256 balance = s_balances[msg.sender];
        uint256 reward = s_rewards[msg.sender];
        s_balances[msg.sender] = 0;
        s_rewards[msg.sender] = 0;
        s_totalSupply -= balance;
        s_StakeToken.safeTransfer(msg.sender, balance);
        emit Withdrawn(msg.sender, balance);
    }

    function emergencyWithdrawAll() external onlyOwner {
        uint256 stakeBalance = s_StakeToken.balanceOf(address(this));
        uint256 rewardBalance = s_RewardToken.balanceOf(address(this));
        
        if(stakeBalance > 0) {
            s_StakeToken.safeTransfer(owner(), stakeBalance);
        }
        if(rewardBalance > 0) {
            s_RewardToken.safeTransfer(owner(), rewardBalance);
        }
    }
}