// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LayerZeroBaseReceiver} from "../../src/points/LayerZeroBaseReceiver.sol";

/// @notice Deploys the LayerZero receiver on Ethereum Sepolia for Optimism checkpoints and configures the OP peer.
contract DeployOpReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address endpoint = vm.envAddress("L1_LAYERZERO_ENDPOINT");
        address aggregator = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");
        address opCollector = vm.envAddress("OP_BURN_COLLECTOR_ADDRESS");
        uint32 opEid = uint32(vm.envUint("OP_LAYERZERO_EID"));

        vm.startBroadcast(deployerKey);

        LayerZeroBaseReceiver receiver = new LayerZeroBaseReceiver(endpoint, aggregator);
        console.log("LayerZero OP receiver deployed:", address(receiver));

        receiver.setTrustedPeer(opEid, _toBytes32(opCollector));
        console.log("OP peer configured (EID %s => %s)", opEid, opCollector);

        vm.stopBroadcast();

        console.log("\nNext steps:");
        console.log(" - PointsAggregator.setAuthorizedCollector(%s, true)", address(receiver));
        console.log(" - OP burn collector setAggregator(%s) / setAggregatorPeer(%s)", address(receiver), address(receiver));
        console.log(" - Export OP_L1_LAYERZERO_RECEIVER_ADDRESS=%s", address(receiver));
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
