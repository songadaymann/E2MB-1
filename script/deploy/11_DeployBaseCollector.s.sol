// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {BaseBurnCollector} from "../../src/points/BaseBurnCollector.sol";

/// @notice Deploys the Base Sepolia burn collector and wires it to the existing L1 PointsAggregator.
contract DeployBaseCollector is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address l1Aggregator = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");
        address endpoint = vm.envAddress("BASE_LAYERZERO_ENDPOINT");
        uint32 l1EndpointId = uint32(vm.envUint("L1_LAYERZERO_EID"));
        bytes memory checkpointOptions;
        try vm.envBytes("BASE_CHECKPOINT_OPTIONS") returns (bytes memory value) {
            checkpointOptions = value;
        } catch {
            checkpointOptions = "";
        }

        vm.startBroadcast(deployerKey);

        BaseBurnCollector collector = new BaseBurnCollector(endpoint, l1Aggregator, l1EndpointId, checkpointOptions);
        console.log("BaseBurnCollector deployed:", address(collector));

        vm.stopBroadcast();

        console.log("\nNext steps:");
        console.log(" - Add eligible Base assets via addEligibleAsset / addEligibleAssetWithDecimals");
        console.log(" - Configure LayerZero peers/options if needed");
        console.log(" - Ensure the L1 LayerZero receiver is set as peer and allowed to call the aggregator");
    }
}
