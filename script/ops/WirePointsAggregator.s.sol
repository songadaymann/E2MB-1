// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {PointsManager} from "../../src/points/PointsManager.sol";
import {PointsAggregator} from "../../src/points/PointsAggregator.sol";

/// @notice Helper script to refresh PointsManager ↔ Aggregator wiring and authorize receivers.
/// @dev Run with `forge script script/ops/WirePointsAggregator.s.sol --broadcast`
///      after `source .env && source deployed.env`.
contract WirePointsAggregator is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address pointsManagerAddr = vm.envAddress("POINTS_MANAGER_ADDRESS");
        address aggregatorAddr = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");
        address baseReceiver = vm.envOr("BASE_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        address opReceiver = vm.envOr("OP_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        address arbReceiver = vm.envOr("ARB_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        address zoraReceiver = vm.envOr("ZORA_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));

        vm.startBroadcast(deployerKey);

        PointsManager pointsManager = PointsManager(pointsManagerAddr);
        PointsAggregator aggregator = PointsAggregator(aggregatorAddr);

        pointsManager.setAggregator(aggregatorAddr);
        console.log("PointsManager aggregator set ->", aggregatorAddr);

        if (baseReceiver != address(0)) {
            aggregator.setAuthorizedCollector(baseReceiver, true);
            console.log("Authorized Base receiver:", baseReceiver);
        }
        if (opReceiver != address(0)) {
            aggregator.setAuthorizedCollector(opReceiver, true);
            console.log("Authorized OP receiver:", opReceiver);
        }
        if (arbReceiver != address(0)) {
            aggregator.setAuthorizedCollector(arbReceiver, true);
            console.log("Authorized ARB receiver:", arbReceiver);
        }
        if (zoraReceiver != address(0)) {
            aggregator.setAuthorizedCollector(zoraReceiver, true);
            console.log("Authorized Zora receiver:", zoraReceiver);
        }

        vm.stopBroadcast();
    }
}
