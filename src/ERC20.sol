// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20 {
    
    address owner;


    constructor() ERC20("Token","TK"){
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner);
        _mint(to, amount);
    }

}