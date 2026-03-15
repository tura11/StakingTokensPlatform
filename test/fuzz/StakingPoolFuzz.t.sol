// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "../../src/StakingPool.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";


contract StakingPoolFuzzTest is Test {
    Tura11ERC20 rewardToken;
    ERC20Mock stakeToken;
    StakingPool pool;
    address owner;
    address user1;
    address user2;



    function setUp() external {
        stakeToken = new ERC20Mock();
        rewardToken = new Tura11ERC20();
        pool = new StakingPool(address(stakeToken), address(rewardToken));

        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

    }



    function testFuzz_StakeMath(uint256 amount) public {
        vm.assume(amount > 0);
        vm.startPrank(user1);
        stakeToken.mint(user1, amount);
        stakeToken.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();

        assertEq(pool.getUserBalance(user1), amount);
        assertEq(pool.getTotalSupply(), amount);

    }


    function testFuzz_Withdraw(uint256 amount) public {
        vm.assume(amount > 1); // we have to assume amount > 1 to make sure we can always withdraw at least one token
        vm.startPrank(user1);
        stakeToken.mint(user1, amount);
        stakeToken.approve(address(pool), amount);
        pool.stake(amount);
        pool.withdraw(amount - 1);
        vm.stopPrank();

        assertEq(pool.getUserBalance(user1),1); // example amount = 1000, amount - 1 = 999 so 1000 - 999 = 1
        assertEq(pool.getTotalSupply(),1);
    }


    function testFuzz_RewardRateCalculation(uint256 reward, uint256 duration) public {
        vm.assume(reward > 0 && reward < 10000000 * 1e18);
        vm.assume(duration > 0 && duration < 30 days);
        vm.startPrank(owner);
        rewardToken.mint(owner, reward);
        rewardToken.approve(address(pool), reward);
        pool.notifyRewardAmount(reward, duration);
        vm.stopPrank();

        assertLe(pool.getRewardRate() * duration, reward);
    }


    function testFuzz_WithdrawDoestNotLoseRewards(uint256 amount) public {
        vm.assume(amount > 0);
        vm.startPrank(owner);
        rewardToken.mint(owner, 1000);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();
        vm.startPrank(user1);
        stakeToken.mint(user1, amount);
        stakeToken.approve(address(pool), amount);
        pool.stake(amount);
        
        vm.warp(block.timestamp + 50);

        uint256 rewardsUser1 = pool.earned(user1);
        pool.withdraw(amount);
        vm.stopPrank();

        assertEq(pool.earned(user1), rewardsUser1);
        assertEq(pool.getUserBalance(user1), 0);
        assertEq(pool.getTotalSupply(), 0);
    }
}