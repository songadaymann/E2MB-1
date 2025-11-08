// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/testnet/mocks/DummyOneOfOne.sol";
import "../../src/testnet/mocks/DummyEdition1155.sol";
import "../../src/testnet/mocks/DummyERC20Burnable.sol";

/// @title DeployBurnMocks
/// @notice Deploys dummy ERC-721, ERC-1155, and ERC-20 contracts for burn-to-points testing
contract DeployBurnMocks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        DummyOneOfOne oneOfOne = new DummyOneOfOne();
        DummyEdition1155 edition = new DummyEdition1155();
        DummyERC20Burnable erc20 = new DummyERC20Burnable();
        vm.stopBroadcast();

        console.log("=== BURN MOCK DEPLOYMENT COMPLETE ===");
        console.log("Deployer:", deployer);
        console.log("DummyOneOfOne:", address(oneOfOne));
        console.log("DummyEdition1155:", address(edition));
        console.log("DummyERC20:", address(erc20));
        console.log("\nRemember to verify and grant mints as needed:");
        console.log("1. cast send %s \"mint(address)\" <recipient>", address(oneOfOne));
        console.log("2. cast send %s \"mintEdition(address,uint256,uint256)\" <recipient> <id> <amount>", address(edition));
        console.log("3. cast send %s \"mint(address,uint256)\" <recipient> <amount>", address(erc20));
    }
}
