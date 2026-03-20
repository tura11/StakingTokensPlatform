// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Tura11ERC20} from "../src/Tura11ERC20.sol";
import {StakingFactory} from "../src/StakingFactory.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy reward token
        Tura11ERC20 rewardToken = new Tura11ERC20();
        console.log("Tura11ERC20 deployed at:", address(rewardToken));

        // 2. Deploy factory
        StakingFactory factory = new StakingFactory(address(rewardToken));
        console.log("StakingFactory deployed at:", address(factory));

        // 3. Deploy mock stake token
        ERC20Mock stakeToken = new ERC20Mock();
        stakeToken.mint(deployer, 1_000_000 * 1e18);
        console.log("ERC20Mock (stakeToken) deployed at:", address(stakeToken));

        // 4. Create pool via factory
        address pool = factory.createPool(address(stakeToken));
        console.log("StakingPool deployed at:", pool);

        // 5. Fund pool with rewards
        rewardToken.approve(pool, 10_000 * 1e18);
        StakingPool(pool).notifyRewardAmount(10_000 * 1e18, 3600);
        console.log("Pool funded with 10,000 T11 for 1 hour");

        vm.stopBroadcast();
    }
}

//   Tura11ERC20 deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3
//   StakingFactory deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
//   ERC20Mock (stakeToken) deployed at: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
//   StakingPool deployed at: 0xCafac3dD18aC6c6e92c921884f9E4176737C052c
//   Pool funded with 10,000 T11 for 1 hour