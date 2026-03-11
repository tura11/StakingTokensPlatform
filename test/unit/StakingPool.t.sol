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


    }


    function testConstructor() public {
        assertEq(address(stakeToken), pool.getStakeTokenAddress());
        assertEq(address(rewardToken), pool.getRewardTokenAddress());
    }


        //STAKE FUNCTION//
    function testStake() public {
        vm.startPrank(user1);
        stakeToken.mint(user1, 1000);
        stakeToken.approve(address(pool), 1000);
        pool.stake(1000);
        assertEq(1000, stakeToken.balanceOf(address(pool)));
        assertEq(pool.getUserBalance(user1), 1000);
        assertEq(pool.getTotalSupply(), 1000);
    }


    function testStakeRevertIfAmountIsZero() public {
        vm.startPrank(user1);
        stakeToken.mint(user1, 1000);
        stakeToken.approve(address(pool), 1000);
        vm.expectRevert(StakingPool.StakingPool__InvalidAmount.selector);
        pool.stake(0);

    }

    function testStakeEmitEvent() public {
        vm.startPrank(user1);
        stakeToken.mint(user1, 1000);
        stakeToken.approve(address(pool), 1000);
        vm.expectEmit(true,false,false,true);
        emit  StakingPool.Staked(user1, 1000);
        pool.stake(1000);
    }
}

