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
    }
}

