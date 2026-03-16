// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IStakingFactory {
    function createPool(address stakeToken) external returns (address);
    function getPool(address stakeToken) external view returns (address);
    function getAllPools() external view returns (address[] memory);
    function owner() external view returns (address);
}
