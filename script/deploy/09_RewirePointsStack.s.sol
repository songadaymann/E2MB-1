// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {PointsManager} from "../../src/points/PointsManager.sol";
import {PointsAggregator} from "../../src/points/PointsAggregator.sol";
import {L1BurnCollector} from "../../src/points/L1BurnCollector.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Deploys a fresh PointsAggregator + L1BurnCollector pair and wires them
///         to the existing PointsManager plus dummy burnable assets.
/// @dev    Run with `forge script --broadcast` after sourcing the env files so the
///         addresses resolve. Assumes the signer owns the PointsManager and holds
///         the dummy assets that need approvals.
contract RewirePointsStack is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        address pointsManagerAddr = vm.envAddress("POINTS_MANAGER_ADDRESS");
        address dummyOneOfOne = vm.envAddress("DUMMY_ONE_OF_ONE_ADDRESS");
        address dummyEdition1155 = vm.envAddress("DUMMY_EDITION1155_ADDRESS");
        address dummyErc20 = vm.envAddress("DUMMY_ERC20_ADDRESS");
        address songADayCollection = vm.envAddress("SONG_A_DAY_COLLECTION_ADDRESS");
        address msongAddress = vm.envAddress("MSONG_ADDRESS");

        // Step 1: Deploy a new aggregator pointed at the active PointsManager.
        PointsAggregator aggregator = new PointsAggregator(pointsManagerAddr);
        console.log("PointsAggregator deployed:", address(aggregator));

        // Step 2: Allow the aggregator contract to credit points.
        PointsManager pointsManager = PointsManager(pointsManagerAddr);
        pointsManager.setAggregator(address(aggregator));
        console.log("PointsManager aggregator set ->", address(aggregator));

        // Step 3: Deploy the L1 burn collector wired to the aggregator.
        L1BurnCollector collector = new L1BurnCollector(address(aggregator), songADayCollection);
        console.log("L1BurnCollector deployed:", address(collector));

        aggregator.setL1BurnCollector(address(collector));
        console.log("Aggregator.l1BurnCollector =", address(collector));

        aggregator.setNftContract(msongAddress);
        console.log("Aggregator.nftContract =", msongAddress);

        address baseReceiver = vm.envOr("BASE_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (baseReceiver == address(0)) {
            baseReceiver = vm.envOr("L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        }
        if (baseReceiver != address(0) && baseReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(baseReceiver, true);
            console.log("Authorized Base L1 receiver =", baseReceiver);
        }

        address opReceiver = vm.envOr("OP_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (opReceiver != address(0) && opReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(opReceiver, true);
            console.log("Authorized OP L1 receiver =", opReceiver);
        }

        address arbReceiver = vm.envOr("ARB_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (arbReceiver != address(0) && arbReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(arbReceiver, true);
            console.log("Authorized ARB L1 receiver =", arbReceiver);
        }

        address zoraReceiver = vm.envOr("ZORA_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (zoraReceiver != address(0) && zoraReceiver != address(collector)) {
            aggregator.setAuthorizedCollector(zoraReceiver, true);
            console.log("Authorized ZORA L1 receiver =", zoraReceiver);
        }

        pointsManager.setRevealQueue(msongAddress);
        pointsManager.setPermutationZeroIndexed(true);
        console.log("PointsManager reveal queue + zero indexing configured.");

        // Step 4: Register eligible burnable assets with their base point values.
        collector.addEligibleAsset(dummyOneOfOne, 100_000);
        collector.addEligibleAsset(dummyEdition1155, 10_000);
        collector.addEligibleAssetWithDecimals(dummyErc20, 1, 18);
        console.log("Eligible assets configured.");

        // Step 5: Give the collector approval to pull + burn test assets.
        IERC721(dummyOneOfOne).setApprovalForAll(address(collector), true);
        IERC1155(dummyEdition1155).setApprovalForAll(address(collector), true);
        IERC20(dummyErc20).approve(address(collector), type(uint256).max);
        console.log("Dummy asset approvals granted.");

        vm.stopBroadcast();

        console.log("\nNext steps:");
        console.log(" - Update deployments/sepolia.json with these new addresses.");
        console.log(" - Call PointsAggregator.directAward or burn flows to sanity check.");
    }
}
