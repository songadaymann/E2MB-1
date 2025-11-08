// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/points/PointsManager.sol";
import "../../src/points/PointsAggregator.sol";

contract ConfigureE2MB is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address msongAddress = vm.envAddress("MSONG_ADDRESS");
        address pointsManagerAddress = vm.envAddress("POINTS_MANAGER_ADDRESS");
        address pointsAggregatorAddress = vm.envAddress("POINTS_AGGREGATOR_ADDRESS");

        address vrfCoordinator = vm.envAddress("SEPOLIA_VRF_COORDINATOR_ADDRESS");
        bytes32 vrfKeyHash = vm.envBytes32("SEPOLIA_VRF_KEY_HASH");
        bytes32 vrfSubscriptionBytes = vm.envBytes32("SEPOLIA_VRF_SUBSCRIPTION_ID");
        uint16 vrfMinConfirmations = uint16(vm.envUint("SEPOLIA_VRF_MIN_CONFIRMATIONS"));
        uint32 vrfCallbackGasLimit = uint32(vm.envUint("SEPOLIA_VRF_CALLBACK_GAS_LIMIT"));
        uint32 vrfNumWords = uint32(vm.envUint("SEPOLIA_VRF_NUM_WORDS"));

        vm.startBroadcast(deployerKey);

        address caller = vm.addr(deployerKey);

        EveryTwoMillionBlocks msong = EveryTwoMillionBlocks(msongAddress);
        PointsManager pointsManager = PointsManager(pointsManagerAddress);
        PointsAggregator aggregator = PointsAggregator(pointsAggregatorAddress);

        // Wire points contracts to the NFT
        msong.setPointsManager(pointsManagerAddress);
        msong.setPointsAggregator(pointsAggregatorAddress);

        address aggregatorOwner = aggregator.owner();
        if (aggregatorOwner == caller) {
            aggregator.setNftContract(msongAddress);
        } else {
            console.log("Skip aggregator.setNftContract, owner is", aggregatorOwner);
        }

        address pointsManagerOwner = pointsManager.owner();
        if (pointsManagerOwner == caller) {
            pointsManager.setAggregator(pointsAggregatorAddress);
            pointsManager.setRevealQueue(msongAddress);
            pointsManager.setPermutationZeroIndexed(true);
        } else {
            console.log("Skip PointsManager owner calls, owner is", pointsManagerOwner);
        }

        // Configure VRF (Chainlink v2.5)
        msong.configureVRF(
            vrfCoordinator,
            vrfKeyHash,
            uint256(vrfSubscriptionBytes),
            vrfMinConfirmations,
            vrfCallbackGasLimit,
            vrfNumWords
        );

        vm.stopBroadcast();

        console.log("EveryTwoMillionBlocks configured:");
        console.log("  PointsManager ->", pointsManagerAddress);
        console.log("  PointsAggregator ->", pointsAggregatorAddress);
        console.log("  VRF Coordinator ->", vrfCoordinator);
        console.log("  Subscription ID ->", vm.toString(uint256(vrfSubscriptionBytes)));
    }
}
