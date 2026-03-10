// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Tura11ERC20} from "./Tura11ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StakingPool} from "./StakingPool.sol";

contract StakingFactory is Ownable {

    error StakingFactory__AddressZero();
    error StakingFactory__PoolAlreadyExists();

    Tura11ERC20 public rewardToken;
    mapping(address => address) public s_pools;
    address[] public s_allPools;
    
    event PoolCreated(address stakedToken, address pool);

    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = Tura11ERC20(_rewardToken);
    }

    function createPool(address stakedToken) external onlyOwner returns (address) {
        if(stakedToken == address(0)) {
            revert StakingFactory__AddressZero();
        }
        if(s_pools[stakedToken] != address(0)) {
            revert StakingFactory__PoolAlreadyExists();
        }
        StakingPool pool = new StakingPool(stakedToken, address(rewardToken));
        s_pools[stakedToken] = address(pool);
        s_allPools.push(address(pool));
        emit PoolCreated(stakedToken, address(pool));
        return address(pool);
    }


}