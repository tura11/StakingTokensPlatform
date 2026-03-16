// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "../../src/StakingPool.sol";
import {Tura11ERC20} from "../../src/Tura11ERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./HandlerPool.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
contract StakingPoolInvariant is StdInvariant, Test {
    Tura11ERC20 rewardToken;
    ERC20Mock stakeToken;
    StakingPool pool;
    Handler handler;

    function setUp() public {
        rewardToken = new Tura11ERC20();
        stakeToken = new ERC20Mock();
        pool = new StakingPool(address(stakeToken), address(rewardToken));
        handler = new Handler(pool, rewardToken, stakeToken);


        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        selectors[2] = Handler.claimReward.selector;
        selectors[3] = Handler.notifyRewardAmount.selector;
        selectors[4] = Handler.warpTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }
    

    /// @notice check if total supply  are always equal to sum of user balances
    function invariant_TotalSupplyAlawysEqualSumOfUserBalances() public view {
        uint256 totalSupply = pool.getTotalSupply();

        address user1 = handler.users(0);
        address user2 = handler.users(1);

        uint256 user1Balance = pool.getUserBalance(user1);
        uint256 user2Balance = pool.getUserBalance(user2);

        assert(totalSupply == user1Balance + user2Balance);
    }

    /// @notice check if contract always has balance T11 tokens for give to users
    function invariant_ContractAlwaysHasBalanceForWithdrawToUsers() public view {
        address user1 = handler.users(0);
        address user2 = handler.users(1);

        uint256 poolRewardTokenBalance = rewardToken.balanceOf(address(pool));
        uint256 user1Rewards = pool.earned(user1);
        uint256 user2Rewards = pool.earned(user2);

        assertGe(poolRewardTokenBalance, user1Rewards + user2Rewards);
    }

    /// @notice check if total reward token balance is always greater than sum of user rewards
    function invariant_TotalRewardDepositedAlwaysGteEarned() public view {
        address user1 = handler.users(0);
        address user2 = handler.users(1);

        assertGe(
            handler.totalRewardDeposited(),
            pool.earned(user1) + pool.earned(user2)
        );
    }
    /// @notice check if total supply of stakeTokens are always equal to sum of user balances
    function invariant_StakeTokenBalanceEqualsSumOfUserBalances() public view {
        address user1 = handler.users(0);
        address user2 = handler.users(1);

        assertEq(
            stakeToken.balanceOf(address(pool)),
            pool.getUserBalance(user1) + pool.getUserBalance(user2)
        );
    }
}