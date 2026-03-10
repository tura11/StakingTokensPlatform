// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract StakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error StakingPool__AddressZero(address token);


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


    function rewardPerToken() public view returns (uint256) {
        uint256 timeDelta = lastTimeRewardApplicable() - s_lastUpdateTime;
        if(s_totalSupply == 0){
            return s_rewardPerTokenStored;
        }else{
            return s_rewardPerTokenStored + (timeDelta * s_rewardRate * 1e18 / totalSupply)
        }

    }




}