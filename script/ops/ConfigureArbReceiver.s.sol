// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IArbLayerZeroReceiver {
    function setTrustedPeer(uint32 srcEid, bytes32 peer) external;
}

contract ConfigureArbReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address receiver = vm.envAddress("ARB_L1_LAYERZERO_RECEIVER_ADDRESS");
        uint32 arbEid = uint32(vm.envUint("ARB_LAYERZERO_EID"));
        address arbCollector = vm.envAddress("ARB_BURN_COLLECTOR_ADDRESS");

        vm.startBroadcast(deployerKey);
        IArbLayerZeroReceiver(receiver).setTrustedPeer(arbEid, _toBytes32(arbCollector));
        vm.stopBroadcast();

        console.log("LayerZero ARB receiver peer set:");
        console.log("  receiver:", receiver);
        console.log("  srcEid  :", arbEid);
        console.log("  peer    :", arbCollector);
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
