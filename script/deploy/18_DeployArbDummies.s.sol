// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {DummyOneOfOne} from "../../src/testnet/mocks/DummyOneOfOne.sol";
import {DummyEdition1155} from "../../src/testnet/mocks/DummyEdition1155.sol";
import {DummyERC20Burnable} from "../../src/testnet/mocks/DummyERC20Burnable.sol";
import {BaseBurnCollector} from "../../src/points/BaseBurnCollector.sol";

/// @notice Deploys Arbitrum Sepolia dummy assets, grants approvals, and registers them with the ARB burn collector.
contract DeployArbDummies is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address collectorAddr = vm.envAddress("ARB_BURN_COLLECTOR_ADDRESS");

        vm.startBroadcast(deployerKey);

        DummyOneOfOne dummy721 = new DummyOneOfOne();
        DummyEdition1155 dummy1155 = new DummyEdition1155();
        DummyERC20Burnable dummy20 = new DummyERC20Burnable();

        console.log("DummyOneOfOne (ARB) deployed:", address(dummy721));
        console.log("DummyEdition1155 (ARB) deployed:", address(dummy1155));
        console.log("DummyERC20Burnable (ARB) deployed:", address(dummy20));

        dummy721.setApprovalForAll(collectorAddr, true);
        dummy1155.setApprovalForAll(collectorAddr, true);
        dummy20.approve(collectorAddr, type(uint256).max);
        console.log("Collector approvals granted.");

        BaseBurnCollector collector = BaseBurnCollector(collectorAddr);
        collector.addEligibleAsset(address(dummy721), 100_000);
        collector.addEligibleAsset(address(dummy1155), 10_000);
        collector.addEligibleAssetWithDecimals(address(dummy20), 1, 18);
        console.log("Collector eligibility configured.");

        vm.stopBroadcast();

        console.log("\nUpdate deployed.env with:");
        console.log("  export ARB_DUMMY_ONE_OF_ONE_ADDRESS=%s", address(dummy721));
        console.log("  export ARB_DUMMY_EDITION1155_ADDRESS=%s", address(dummy1155));
        console.log("  export ARB_DUMMY_ERC20_ADDRESS=%s", address(dummy20));
    }
}
