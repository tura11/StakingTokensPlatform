// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Tura11ERC20 is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 10000000 * 1e18;

    constructor() ERC20("Tura11", "T11") Ownable(msg.sender) {
        _mint(owner(), INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
