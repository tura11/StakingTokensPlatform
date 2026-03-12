// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
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

        vm.startPrank(user1);
        stakeToken.mint(user1, 10000);
        stakeToken.approve(address(pool), 10000);
        vm.stopPrank();


        vm.startPrank(user2);
        stakeToken.mint(user2, 10000);
        stakeToken.approve(address(pool), 10000);
        vm.stopPrank();

    }


    function testConstructor() public {
        assertEq(address(stakeToken), pool.getStakeTokenAddress());
        assertEq(address(rewardToken), pool.getRewardTokenAddress());
    }

    function testConstructorRevertIfStakeTokenIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(StakingPool.StakingPool__AddressZero.selector, address(0))
        );
        new StakingPool(address(0), address(rewardToken));
    }

    function testConstructorRevertIfRewardTokenIsZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(StakingPool.StakingPool__AddressZero.selector, address(0))
        );
        new StakingPool(address(stakeToken), address(0));
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

    // ============================================================================
    // MATH TIME
    // ============================================================================

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



    function testUsersEarnProportionaly() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100); // 10 t11 per second
        vm.stopPrank();
        vm.prank(user1);
        pool.stake(250); // 25% shares
        vm.prank(user2);
        pool.stake(750); // 75% shares 

        vm.warp(block.timestamp + 50);


        uint256 user1Earned = pool.earned(user1); //  250 * 0.5e18 / 1e18 = 125
        uint256 user2Earned = pool.earned(user2); //  750 * 0.5e18 / 1e18 = 375
        assertEq(user1Earned, 125);
        assertEq(user2Earned, 375);
    }


    // ============================================================================
    // CLAIM REWARD TESTS
    // ============================================================================



    function testClaimReward() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();

        vm.startPrank(user1);
        pool.stake(1000);

        vm.warp(block.timestamp + 50);

        uint256 userRewards = pool.earned(user1);

        assertEq(userRewards, 500);

        pool.claimReward();

        assertEq(pool.getUserReward(user1), 0);
        assertEq(rewardToken.balanceOf(user1), 500);

    }




    // ============================================================================
    // lastTimeRewardApplicable TESTS
    // ============================================================================

    function testLastTimeRewardApplicableAfterPeriodEnd() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100); 
        vm.stopPrank();

        vm.warp(block.timestamp + 200); 

        assertEq(pool.lastTimeRewardApplicable(), pool.getPeriodFinish());
    }


    function testLastTimeRewardApplicableDuringPeriod() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();

        vm.warp(block.timestamp + 50); 

        assertEq(pool.lastTimeRewardApplicable(), block.timestamp);
    }


    // ============================================================================
    // MODIFIER TESTS
    // ============================================================================

    function testUpdateRewardModifierUpdatesUserState() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();

        vm.startPrank(user1);
        pool.stake(1000);
        vm.warp(block.timestamp + 50);
        pool.stake(1); 

        assertEq(pool.getUserReward(user1), 500);
        assertEq(pool.getUserRewardPerTokenPaid(user1), pool.getRewardPerToken()); 
        vm.stopPrank();
    }


    // ============================================================================
    // EXIT TESTS
    // ============================================================================


    function testExit() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();
        vm.startPrank(user1);
        pool.stake(1000);
        vm.warp(block.timestamp + 50);
        pool.exit();
        assertEq(stakeToken.balanceOf(user1), 10000); //user1 mints 10000 stake tokens
        assertEq(rewardToken.balanceOf(user1), 500);  //user1 gets 500 reward tokens
    }

    // ============================================================================
    // EMERGENCY WITHDRAW TESTS
    // ============================================================================
    function testEmergencyWithdraw() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();
        vm.startPrank(user1);
        pool.stake(1000);
        vm.warp(block.timestamp + 50);
        pool.emergencyWithdraw();
        assertEq(stakeToken.balanceOf(user1), 10000); //user1 mints 10000 stake tokens
        assertEq(rewardToken.balanceOf(user1), 0);  //user1 lost all reward tokens
    }


    function testEmergencyWithdrawAll() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        pool.notifyRewardAmount(1000, 100);
        vm.stopPrank();
        vm.prank(user1);
        pool.stake(1000);
        vm.prank(user2);
        pool.stake(1000);
        vm.warp(block.timestamp + 100); //500 rewards token user1, 500 rewards token user2, and 1000 stake token user1 and user2
        console.log("rewardToken.balanceOf() = ", rewardToken.balanceOf(address(pool)));
        vm.prank(owner);
        pool.emergencyWithdrawAll();
        assertEq(stakeToken.balanceOf(owner), 3000); //owner has  1000 stake tokens
        assertEq(rewardToken.balanceOf(owner), 10000000 * 1e18);  //owner has  10000000 * 1e18 reward tokens minted from Tura11ERC20.sol
    }

    // ============================================================================
    // NotifyRewardAmount TESTS
    // ============================================================================

    function testNotifyREwardAmountRevertsDurationTooLong() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 1000);
        vm.expectRevert(StakingPool.StakingPool__DurationTooLong.selector);
        pool.notifyRewardAmount(1000, 31 days);
    }

    function testNotifyRewardAmountBeforePeriodFinished() public {
        vm.startPrank(owner);
        rewardToken.approve(address(pool), 2000);
        pool.notifyRewardAmount(1000, 100);
        
        vm.warp(block.timestamp + 50);

        pool.notifyRewardAmount(1000, 100); 
        assertEq(pool.getRewardRate(), 15);
        vm.stopPrank();
    }

    function testNotifyRewardAmountRevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        pool.notifyRewardAmount(1000, 100);
    }
}

