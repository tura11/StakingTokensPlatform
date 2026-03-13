// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {StakingFactory} from "../../src/StakingFactory.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IStakingPool} from "../../src/interfaces/IStakingPool.sol";


contract StakingFactoryFuzzTest is Test {
    StakingFactory factory;
    ERC20Mock stakingToken;
    Tura11ERC20 rewardToken;
    IStakingPool pool;
    address owner;

    function setUp() public {
        rewardToken = new Tura11ERC20();
        stakingToken = new ERC20Mock();
        factory = new StakingFactory(address(rewardToken));
        owner = address(this);
    }

    function testFuzz_CreatePool(address stakeToken) public {
        vm.assume(stakeToken != address(0));
        pool = IStakingPool(factory.createPool(stakeToken));
        assertEq(factory.getPool(stakeToken), address(pool));
        assertEq(factory.getAllPools()[0], address(pool));
    }


}