// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


interface IStakingPool {


    function stake(address amount) external;
    function withdraw(address amount) external;
    function claimReward() external;
    function rewardPerToken() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function lastTimeRewardApplicable() external view returns (uint256);
    function exit() external;
    function emergencyWithdraw() external;
    function emergencyWithdrawAll() external;
    function notifyRewardAmount(uint256 amount, uint256 rewardDuration) external;
    function getUserBalance(address account) external view returns (uint256);
    function getUserReward(address account) external view returns (uint256);
    function getUserRewardPerTokenPaid(address account) external view returns (uint256);
    function getRewardPerToken() external view returns (uint256);
    function getRewardRate() external view returns (uint256);
    function getTotalSupply() external view returns (uint256);
    function getPeriodFinish() external view returns (uint256);
    function getRewardTokenAddress() external view returns (address);
    function getStakeTokenAddress() external view returns (address);











}