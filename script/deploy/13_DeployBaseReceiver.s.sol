// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LayerZeroBaseReceiver} from "../../src/points/LayerZeroBaseReceiver.sol";

/// @notice Deploys the LayerZero receiver on Ethereum Sepolia and configures the Base peer.
contract DeployBaseReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address endpoint = vm.envAddress("L1_LAYERZERO_ENDPOINT");
        address aggregator = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");
        address baseCollector = vm.envAddress("BASE_BURN_COLLECTOR_ADDRESS");
        uint32 baseEid = uint32(vm.envUint("BASE_LAYERZERO_EID"));

        vm.startBroadcast(deployerKey);

        LayerZeroBaseReceiver receiver = new LayerZeroBaseReceiver(endpoint, aggregator);
        console.log("LayerZeroBaseReceiver deployed:", address(receiver));

        receiver.setTrustedPeer(baseEid, _toBytes32(baseCollector));
        console.log("Base peer configured (EID %s => %s)", baseEid, baseCollector);

        vm.stopBroadcast();

        console.log("\nNext steps:");
        console.log(" - PointsAggregator.setL1BurnCollector(%s)", address(receiver));
        console.log(" - BaseBurnCollector.setAggregator(%s) or setAggregatorPeer()", address(receiver));
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
