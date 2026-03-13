// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {StakingFactory} from "../../src/StakingFactory.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IStakingPool} from "../../src/interfaces/IStakingPool.sol";



contract StakingFactoryTest is Test {
    Tura11ERC20 rewardToken;
    ERC20Mock stakeToken;
    StakingFactory factory;
    IStakingPool pool;
    address owner;
    address user1;


    function setUp() public {
        rewardToken = new Tura11ERC20();
        stakeToken = new ERC20Mock();
        factory = new StakingFactory(address(rewardToken));
        owner = address(this);
        user1 = makeAddr("user1");
    }


    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================
    function testConstructor() public {
        assertEq(factory.getRewardToken(), address(rewardToken));
    }

    function testConstructorRevertIfRewardTokenAddressZero() public {
        vm.expectRevert(StakingFactory.StakingFactory__AddressZero.selector);
        new StakingFactory(address(0));
    }

    // ============================================================================
    // CREATE POOL TESTS
    // ============================================================================

    function testCreatePool() public {
        pool = IStakingPool(factory.createPool(address(stakeToken)));
        assertEq(pool.owner(), factory.owner());
        assertEq(factory.getPool(address(stakeToken)), address(pool));
        assertEq(factory.getAllPools()[0], address(pool));
    }

   function testCreateSecondPool() public {
        ERC20Mock stakeToken2 = new ERC20Mock();
        
        pool = IStakingPool(factory.createPool(address(stakeToken)));
        IStakingPool pool2 = IStakingPool(factory.createPool(address(stakeToken2)));

        assertEq(pool.owner(), factory.owner());
        assertEq(factory.getPool(address(stakeToken)), address(pool));
        assertEq(factory.getAllPools()[0], address(pool));

        assertEq(pool2.owner(), factory.owner());
        assertEq(factory.getPool(address(stakeToken2)), address(pool2));
        assertEq(factory.getAllPools()[1], address(pool2));
    }

    function testCreatePoolRevertIfAddressZero() public {
        vm.expectRevert(StakingFactory.StakingFactory__AddressZero.selector);
        factory.createPool(address(0));
    }


    function testCreatePoolRevertIfPoolAlreadyExists() public {
        factory.createPool(address(stakeToken));
        vm.expectRevert(StakingFactory.StakingFactory__PoolAlreadyExists.selector);
        factory.createPool(address(stakeToken));
    }

    function testPoolCanOnlyBeCreatedByOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        factory.createPool(address(stakeToken));
        vm.stopPrank();
    }


}