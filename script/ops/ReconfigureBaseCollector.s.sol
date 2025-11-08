// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IBaseBurnCollector {
    function setAggregator(address newAggregator) external;
    function addEligibleAsset(address asset, uint256 baseValue) external;
    function addEligibleAssetWithDecimals(address asset, uint256 baseValue, uint8 decimalsHint) external;
}

interface IERC721Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IERC1155Like {
    function setApprovalForAll(address operator, bool approved) external;
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ReconfigureBaseCollector is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address collector = vm.envAddress("BASE_BURN_COLLECTOR_ADDRESS");
        address receiver = vm.envOr("BASE_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (receiver == address(0)) {
            receiver = vm.envOr("L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        }
        require(receiver != address(0), "Base receiver address not set");
        address dummy721 = vm.envAddress("BASE_DUMMY_ONE_OF_ONE_ADDRESS");
        address dummy1155 = vm.envAddress("BASE_DUMMY_EDITION1155_ADDRESS");
        address dummy20 = vm.envAddress("BASE_DUMMY_ERC20_ADDRESS");

        vm.startBroadcast(deployerKey);

        IBaseBurnCollector baseCollector = IBaseBurnCollector(collector);
        baseCollector.setAggregator(receiver);
        baseCollector.addEligibleAsset(dummy721, 100_000);
        baseCollector.addEligibleAsset(dummy1155, 10_000);
        baseCollector.addEligibleAssetWithDecimals(dummy20, 1, 18);

        IERC721Like(dummy721).setApprovalForAll(collector, true);
        IERC1155Like(dummy1155).setApprovalForAll(collector, true);
        IERC20Like(dummy20).approve(collector, type(uint256).max);

        vm.stopBroadcast();

        console.log("Base collector reconfigured:", collector);
        console.log("  Aggregator/peer:", receiver);
        console.log("  Dummy approvals refreshed");
    }
}
