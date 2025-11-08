// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IArbBurnCollector {
    function setAggregator(address newAggregator) external;
    function addEligibleAsset(address asset, uint256 baseValue) external;
    function addEligibleAssetWithDecimals(address asset, uint256 baseValue, uint8 decimalsHint) external;
}

interface IArbERC721Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IArbERC1155Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IArbERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ReconfigureArbCollector is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address collector = vm.envAddress("ARB_BURN_COLLECTOR_ADDRESS");
        address receiver = vm.envAddress("ARB_L1_LAYERZERO_RECEIVER_ADDRESS");
        address dummy721 = vm.envAddress("ARB_DUMMY_ONE_OF_ONE_ADDRESS");
        address dummy1155 = vm.envAddress("ARB_DUMMY_EDITION1155_ADDRESS");
        address dummy20 = vm.envAddress("ARB_DUMMY_ERC20_ADDRESS");

        vm.startBroadcast(deployerKey);

        IArbBurnCollector arbCollector = IArbBurnCollector(collector);
        arbCollector.setAggregator(receiver);
        arbCollector.addEligibleAsset(dummy721, 100_000);
        arbCollector.addEligibleAsset(dummy1155, 10_000);
        arbCollector.addEligibleAssetWithDecimals(dummy20, 1, 18);

        IArbERC721Like(dummy721).setApprovalForAll(collector, true);
        IArbERC1155Like(dummy1155).setApprovalForAll(collector, true);
        IArbERC20Like(dummy20).approve(collector, type(uint256).max);

        vm.stopBroadcast();

        console.log("ARB burn collector reconfigured:", collector);
        console.log("  Aggregator/peer:", receiver);
        console.log("  Dummy approvals refreshed");
    }
}
