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
}