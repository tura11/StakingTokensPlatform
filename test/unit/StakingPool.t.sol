// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test} from "forge-std/Test.sol";
import {StakingPool} from "../../src/StakingPool.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";





contract StakingPoolTest is Test {

    ERC20Mock stakeToken;
    Tura11ERC20 rewardToken;
    StakingPool pool;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        stakeToken = new ERC20Mock();
        rewardToken = new Tura11ERC20();
        pool = new StakingPool(address(stakeToken), address(rewardToken));

        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        stakeToken.mint(owner, 1000);
        rewardToken.mint(owner, 1000);

        vm.startPrank(user1);
        stakeToken.mint(user1, 10000);
        stakeToken.approve(address(pool), 10000);
        vm.stopPrank();


    }


    function testConstructor() public {
        assertEq(address(stakeToken), pool.getStakeTokenAddress());
        assertEq(address(rewardToken), pool.getRewardTokenAddress());
    }


    // ============================================================================
    // STAKING TESTS
    // ============================================================================
    function testStake() public {
        vm.startPrank(user1);
        pool.stake(1000);
        assertEq(1000, stakeToken.balanceOf(address(pool)));
        assertEq(pool.getUserBalance(user1), 1000);
        assertEq(pool.getTotalSupply(), 1000);
    }


    function testStakeRevertIfAmountIsZero() public {
        vm.startPrank(user1);
        vm.expectRevert(StakingPool.StakingPool__InvalidAmount.selector);
        pool.stake(0);

    }

    function testStakeEmitEvent() public {
        vm.startPrank(user1);
        vm.expectEmit(true,false,false,true);
        emit  StakingPool.Staked(user1, 1000);
        pool.stake(1000);
    }


    // ============================================================================
    // WITHDRAW TESTS
    // ============================================================================

    function testWithdraw() public {
        vm.startPrank(user1);
        pool.stake(1000);
        pool.withdraw(500);
        assertEq(500, stakeToken.balanceOf(address(pool)));
        assertEq(pool.getUserBalance(user1), 500);
        assertEq(pool.getTotalSupply(), 500);
    }

    function testWithdrawRevertInvalidAmount() public {
        vm.startPrank(user1);
        pool.stake(1000);
        vm.expectRevert(StakingPool.StakingPool__InvalidAmount.selector);
        pool.withdraw(0);
    }


    function testWithdrawRevertIfBalanceTooLow() public {
        vm.startPrank(user1);
        pool.stake(1000);
        vm.expectRevert(StakingPool.StakingPool__BalanceTooLow.selector);
        pool.withdraw(1500);
    }


    function testWithdrawEmitEvent() public {
        vm.startPrank(user1);
        pool.stake(1000);
        vm.expectEmit(true,false,false,true);
        emit  StakingPool.Withdrawn(user1, 500);
        pool.withdraw(500);
    }

    function testEarnedAfterTime() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        uint256 rewardRate = pool.getRewardRate();
        assertEq(rewardRate, 10); //  1000/100
        vm.stopPrank();
        vm.startPrank(user1);
        pool.stake(1000);
        uint256 userEarned = pool.earned(user1);
        uint256 rewardPerTokenBefore = pool.rewardPerToken();
        assertEq(userEarned, 0);
        assertEq(rewardPerTokenBefore, 0); 
        vm.warp(block.timestamp + 50);
        uint256 rewardPerTokenAfter = pool.rewardPerToken();
        uint256 userEarnedAfter = pool.earned(user1);
        assertEq(userEarnedAfter, 500); // 1000 * 0.5e18 / 1e18 = 500
        assertEq(rewardPerTokenAfter, 0.5e18); // 50 * 10 * 1e18 /1000;
        vm.stopPrank();
    }
}

