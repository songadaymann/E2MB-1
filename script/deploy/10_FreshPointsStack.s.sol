// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {EveryTwoMillionBlocks} from "../../src/core/EveryTwoMillionBlocks.sol";
import {PointsManager} from "../../src/points/PointsManager.sol";
import {PointsAggregator} from "../../src/points/PointsAggregator.sol";
import {L1BurnCollector} from "../../src/points/L1BurnCollector.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Deploys a brand-new PointsManager + PointsAggregator + L1BurnCollector stack
///         owned by the caller, wires it into the live E2MB contract, and configures
///         dummy burnable assets plus approvals.
contract FreshPointsStack is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("MSONG_ADDRESS");
        address dummyOneOfOne = vm.envAddress("DUMMY_ONE_OF_ONE_ADDRESS");
        address dummyEdition1155 = vm.envAddress("DUMMY_EDITION1155_ADDRESS");
        address dummyErc20 = vm.envAddress("DUMMY_ERC20_ADDRESS");
        address songADayCollection = vm.envAddress("SONG_A_DAY_COLLECTION_ADDRESS");

        vm.startBroadcast(deployerKey);

        // 1. Deploy new PointsManager owned by the deployer.
        PointsManager pointsManager = new PointsManager();
        console.log("PointsManager deployed:", address(pointsManager));

        // 2. Deploy PointsAggregator pointed at the new manager.
        PointsAggregator aggregator = new PointsAggregator(address(pointsManager));
        console.log("PointsAggregator deployed:", address(aggregator));

        // 3. Allow aggregator to credit points.
        pointsManager.setAggregator(address(aggregator));
        console.log("PointsManager aggregator set.");

        // 4. Deploy L1 burn collector wired to the aggregator.
        L1BurnCollector collector = new L1BurnCollector(address(aggregator), songADayCollection);
        aggregator.setL1BurnCollector(address(collector));
        console.log("L1BurnCollector deployed:", address(collector));

        address baseReceiver = vm.envOr("BASE_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (baseReceiver == address(0)) {
            baseReceiver = vm.envOr("L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        }
        if (baseReceiver != address(0) && baseReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(baseReceiver, true);
            console.log("Authorized Base L1 receiver:", baseReceiver);
        }

        address opReceiver = vm.envOr("OP_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (opReceiver != address(0) && opReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(opReceiver, true);
            console.log("Authorized OP L1 receiver:", opReceiver);
        }

        address arbReceiver = vm.envOr("ARB_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (arbReceiver != address(0) && arbReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(arbReceiver, true);
            console.log("Authorized ARB L1 receiver:", arbReceiver);
        }

        address zoraReceiver = vm.envOr("ZORA_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (zoraReceiver != address(0) && zoraReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(zoraReceiver, true);
            console.log("Authorized ZORA L1 receiver:", zoraReceiver);
        }

        // 5. Register eligible dummy assets (normalized ratio: 1 ERC721 = 10 ERC1155 = 100k ERC20).
        collector.addEligibleAsset(dummyOneOfOne, 100_000);
        collector.addEligibleAsset(dummyEdition1155, 10_000);
        collector.addEligibleAssetWithDecimals(dummyErc20, 1, 18);
        console.log("Dummy assets registered (ERC721=100k, ERC1155=10k, ERC20=1 @18 decimals).");

        // 6. Grant approvals so the collector can pull burns.
        IERC721(dummyOneOfOne).setApprovalForAll(address(collector), true);
        IERC1155(dummyEdition1155).setApprovalForAll(address(collector), true);
        IERC20(dummyErc20).approve(address(collector), type(uint256).max);
        console.log("Collector approvals granted.");

        // 7. Point the live NFT to the new PointsManager.
        EveryTwoMillionBlocks msong = EveryTwoMillionBlocks(nftAddress);
        msong.setPointsManager(address(pointsManager));
        console.log("EveryTwoMillionBlocks now uses new PointsManager.");

        vm.stopBroadcast();

        // Guidance for follow-up bookkeeping.
        console.log("\nUpdate deployments/sepolia.json with:");
        console.log("  \"PointsManager\":", address(pointsManager));
        console.log("  \"PointsAggregator\":", address(aggregator));
        console.log("  \"L1BurnCollector\":", address(collector));
        console.log("Then resync deployed env files and rerun burn tests.");
    }
}
