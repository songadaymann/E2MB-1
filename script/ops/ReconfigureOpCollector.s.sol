// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IOpBurnCollector {
    function setAggregator(address newAggregator) external;
    function addEligibleAsset(address asset, uint256 baseValue) external;
    function addEligibleAssetWithDecimals(address asset, uint256 baseValue, uint8 decimalsHint) external;
}

interface IOpERC721Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IOpERC1155Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IOpERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ReconfigureOpCollector is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address collector = vm.envAddress("OP_BURN_COLLECTOR_ADDRESS");
        address receiver = vm.envAddress("OP_L1_LAYERZERO_RECEIVER_ADDRESS");
        address dummy721 = vm.envAddress("OP_DUMMY_ONE_OF_ONE_ADDRESS");
        address dummy1155 = vm.envAddress("OP_DUMMY_EDITION1155_ADDRESS");
        address dummy20 = vm.envAddress("OP_DUMMY_ERC20_ADDRESS");

        vm.startBroadcast(deployerKey);

        IOpBurnCollector opCollector = IOpBurnCollector(collector);
        opCollector.setAggregator(receiver);
        opCollector.addEligibleAsset(dummy721, 100_000);
        opCollector.addEligibleAsset(dummy1155, 10_000);
        opCollector.addEligibleAssetWithDecimals(dummy20, 1, 18);

        IOpERC721Like(dummy721).setApprovalForAll(collector, true);
        IOpERC1155Like(dummy1155).setApprovalForAll(collector, true);
        IOpERC20Like(dummy20).approve(collector, type(uint256).max);

        vm.stopBroadcast();

        console.log("OP burn collector reconfigured:", collector);
        console.log("  Aggregator/peer:", receiver);
        console.log("  Dummy approvals refreshed");
    }
}
