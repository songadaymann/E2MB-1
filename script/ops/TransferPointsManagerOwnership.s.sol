// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {PointsManager} from "../../src/points/PointsManager.sol";

/// @notice Transfers PointsManager ownership to the active deployer (0xAd9f…) so we can rewire the stack.
contract TransferPointsManagerOwnership is Script {
    function run() external {
        uint256 ownerKey = vm.envUint("SECONDARY_PRIVATE_KEY");
        vm.startBroadcast(ownerKey);

        address pointsManagerAddr = vm.envAddress("POINTS_MANAGER_ADDRESS");
        address newOwner = vm.envAddress("DEPLOYER_ADDRESS");

        PointsManager(pointsManagerAddr).transferOwnership(newOwner);
        console.log("PointsManager ownership transferred to:", newOwner);

        vm.stopBroadcast();
    }
}
