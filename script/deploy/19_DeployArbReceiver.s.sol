// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LayerZeroBaseReceiver} from "../../src/points/LayerZeroBaseReceiver.sol";

/// @notice Deploys the LayerZero receiver on Ethereum Sepolia for Arbitrum checkpoints and configures the ARB peer.
contract DeployArbReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address endpoint = vm.envAddress("L1_LAYERZERO_ENDPOINT");
        address aggregator = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");
        address arbCollector = vm.envAddress("ARB_BURN_COLLECTOR_ADDRESS");
        uint32 arbEid = uint32(vm.envUint("ARB_LAYERZERO_EID"));

        vm.startBroadcast(deployerKey);

        LayerZeroBaseReceiver receiver = new LayerZeroBaseReceiver(endpoint, aggregator);
        console.log("LayerZero ARB receiver deployed:", address(receiver));

        receiver.setTrustedPeer(arbEid, _toBytes32(arbCollector));
        console.log("ARB peer configured (EID %s => %s)", arbEid, arbCollector);

        vm.stopBroadcast();

        console.log("\nNext steps:");
        console.log(" - PointsAggregator.setAuthorizedCollector(%s, true)", address(receiver));
        console.log(" - ARB burn collector setAggregator(%s) / setAggregatorPeer(%s)", address(receiver), address(receiver));
        console.log(" - Export ARB_L1_LAYERZERO_RECEIVER_ADDRESS=%s", address(receiver));
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
