// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Tura11ERC20} from "./Tura11ERC20.sol";
contract StakingFactory is Ownable {
    error StakingPool__AddressZero(address token);
    IERC20 s_StakeToken;
    Tura11ERC20 s_RewardToken;


    constructor(address _stakeToken, address _rewardToken) Ownable(msg.sender) {
        if(_stakeToken == address(0)) {
            revert StakingPool__AddressZero(_stakeToken);
        }
        if(_rewardToken == address(0)) {
            revert StakingPool__AddressZero(_rewardToken);
        }
        s_StakeToken = IERC20(_stakeToken);
        s_RewardToken = Tura11ERC20(_rewardToken);
    }


}