// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// @author  Tura11
// @notice  T11 is a proprietary ERC20 token used as the reward asset in this protocol.

import {Tura11ERC20} from "./Tura11ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StakingPool} from "./StakingPool.sol";

/**
 * @title   StakingFactory
 * @author  Tura11
 * @notice  Deploys and registers StakingPool contracts for any ERC20 token.
 *          Each pool distributes T11 as its reward asset.
 * @dev     Factory is responsible only for deployment and registry.
 *          Ownership of each deployed pool is immediately transferred to the
 *          Factory owner (EOA / multisig), so pool admin functions such as
 *          notifyRewardAmount() and emergencyWithdrawAll() are called directly
 *          on the pool — not proxied through this contract.
 */
contract StakingFactory is Ownable {

    // =========================================================================
    // Errors
    // =========================================================================

    /**
     * @notice Thrown when address(0) is supplied as the reward token or staked token.
     */
    error StakingFactory__AddressZero();

    /**
     * @notice Thrown when a pool for the given staked token already exists in the registry.
     */
    error StakingFactory__PoolAlreadyExists();

    // =========================================================================
    // State variables
    // =========================================================================

    /**
     * @notice T11 — the proprietary ERC20 reward token injected into every deployed pool.
     */
    Tura11ERC20 public rewardToken;

    /**
     * @notice Maps a staked token address to its corresponding StakingPool address.
     */
    mapping(address => address) public s_pools;

    /**
     * @notice Ordered list of all deployed StakingPool addresses.
     */
    address[] public s_allPools;

    // =========================================================================
    // Events
    // =========================================================================

    /**
     * @notice Emitted when a new StakingPool is deployed and registered.
     * @param  stakedToken Address of the ERC20 token users will deposit.
     * @param  pool        Address of the newly deployed StakingPool.
     */
    event PoolCreated(address indexed stakedToken, address indexed pool);

    // =========================================================================
    // Constructor
    // =========================================================================

    /**
     * @notice Deploys the Factory and sets the T11 reward token.
     * @dev    Reverts on address(0) to prevent deploying a factory that would
     *         produce broken pools with no reward token.
     * @param  _rewardToken Address of the T11 ERC20 reward token.
     */
    constructor(address _rewardToken) Ownable(msg.sender) {
        if (_rewardToken == address(0)) revert StakingFactory__AddressZero();
        rewardToken = Tura11ERC20(_rewardToken);
    }

    // =========================================================================
    // External functions
    // =========================================================================

    /**
     * @notice Deploys a new StakingPool for `stakedToken` and registers it in the factory.
     * @dev    Pool ownership is transferred to the Factory owner immediately after deployment,
     *         so the EOA / multisig can call notifyRewardAmount(), emergencyWithdrawAll(),
     *         and any other owner-gated functions directly on the pool.
     *         The Factory retains no administrative control over deployed pools.
     * @param  stakedToken ERC20 token that users will stake in the new pool.
     * @return Address of the newly deployed StakingPool.
     */
    function createPool(address stakedToken) external onlyOwner returns (address) {
        if (stakedToken == address(0)) revert StakingFactory__AddressZero();
        if (s_pools[stakedToken] != address(0)) revert StakingFactory__PoolAlreadyExists();

        StakingPool pool = new StakingPool(stakedToken, address(rewardToken));
        pool.transferOwnership(owner());

        s_pools[stakedToken] = address(pool);
        s_allPools.push(address(pool));

        emit PoolCreated(stakedToken, address(pool));
        return address(pool);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /**
     * @notice Returns the StakingPool address for a given staked token.
     * @param  stakedToken ERC20 token to look up.
     * @return Pool address, or address(0) if no pool exists for this token.
     */
    function getPool(address stakedToken) external view returns (address) {
        return s_pools[stakedToken];
    }

    /**
     * @notice Returns all deployed StakingPool addresses.
     * @return Array of pool addresses in deployment order.
     */
    function getAllPools() external view returns (address[] memory) {
        return s_allPools;
    }

    function getRewardToken() external view returns (address) {
        return address(rewardToken);
    }
}