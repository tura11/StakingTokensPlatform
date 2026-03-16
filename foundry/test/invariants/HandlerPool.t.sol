// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "../../src/StakingPool.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    StakingPool pool;
    Tura11ERC20 rewardToken;
    ERC20Mock stakeToken;

    address[] public users = new address[](2);
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalRewardDeposited;
    uint256 public constant MAX_AMOUNT = 10_000_000 * 1e18;

    constructor(StakingPool _pool, Tura11ERC20 _rewardToken, ERC20Mock _stakeToken) {
        pool = _pool;
        rewardToken = _rewardToken;
        stakeToken = _stakeToken;
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
    }

    function deposit(uint256 userIndex, uint256 amount) public {
        address user = users[bound(userIndex, 0, users.length - 1)];
        amount = bound(amount, 1, MAX_AMOUNT);

        stakeToken.mint(user, amount);

        vm.startPrank(user);
        stakeToken.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();

        totalDeposited += amount;
    }

    function withdraw(uint256 userIndex, uint256 amount) public {
        address user = users[bound(userIndex, 0, users.length - 1)];

        uint256 userBalance = pool.getUserBalance(user);
        if (userBalance == 0) return;

        amount = bound(amount, 1, userBalance);

        vm.prank(user);
        pool.withdraw(amount);

        totalWithdrawn += amount;
    }

    function claimReward(uint256 userIndex) public {
        address user = users[bound(userIndex, 0, users.length - 1)];

        if (pool.earned(user) == 0) return;

        vm.prank(user);
        pool.claimReward();
    }

    function notifyRewardAmount(uint256 reward, uint256 duration) public {
        reward = bound(reward, 1, MAX_AMOUNT);
        duration = bound(duration, 1, 30 days);

        address owner = pool.owner();
        deal(address(rewardToken), owner, reward);

        vm.startPrank(owner);
        rewardToken.approve(address(pool), reward);
        pool.notifyRewardAmount(reward, duration);
        vm.stopPrank();

        totalRewardDeposited += reward;
    }

    function warpTime(uint256 seconds_) public {
        seconds_ = bound(seconds_, 1, 30 days);
        vm.warp(block.timestamp + seconds_);
    }
}
