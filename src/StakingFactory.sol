// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {Tura11ERC20} from "./Tura11ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingFactory {

    error StakingFactory__AddressZero();
    error StakingFactory__PoolAlreadyExists();

    address public s_stakedToken;
    Tura11ERC20 public rewardToken;
    mapping(address => address) public s_pools;
    
    

    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = Tura11ERC20(_rewardToken);
    }

    function createPool(address _stakedToken) external onlyOwner {
        if(s_stakedToken != address(0)) {
            revert StakingFactory__AddressZero();
        }
        if(s_pools[_stakedToken] != address(0)) {
            revert StakingFactory__PoolAlreadyExists();
        }
        s_stakedToken = _stakedToken;
    }


}