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

    address[] users = new address[](2);
    uint256 public totalDeposited;
    uint256 public totalWithdraw;
    uint256 public constant MAX_DEPOSIT = 10000000 * 1e18;
    uint256 public constant MAX_WITHDRAW = 1000000 * 1e18;

    constructor(StakingPool _pool, Tura11ERC20 _rewardToken, ERC20Mock _stakeToken) {
        pool = _pool;
        rewardToken = _rewardToken;
        stakeToken = _stakeToken;
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
    }


    function deposit(uint256 userIndex, uint256 amount) public {
        address user = users[userIndex % users.length];
        amount = bound(amount, 0, MAX_DEPOSIT);

        vm.startPrank(user);
        stakeToken.mint(user, amount);
        stakeToken.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();

        totalDeposited += amount;


    }

}