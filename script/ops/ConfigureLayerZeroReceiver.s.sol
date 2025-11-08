// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface ILayerZeroBaseReceiver {
    function setTrustedPeer(uint32 srcEid, bytes32 peer) external;
}

contract ConfigureLayerZeroReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address receiver = vm.envOr("BASE_L1_LAYERZERO_RECEIVER_ADDRESS", address(0));
        if (receiver == address(0)) {
            receiver = vm.envAddress("L1_LAYERZERO_RECEIVER_ADDRESS");
        }
        uint32 baseEid = uint32(vm.envUint("BASE_LAYERZERO_EID"));
        address baseCollector = vm.envAddress("BASE_BURN_COLLECTOR_ADDRESS");

        vm.startBroadcast(deployerKey);
        ILayerZeroBaseReceiver(receiver).setTrustedPeer(baseEid, _toBytes32(baseCollector));
        vm.stopBroadcast();

        console.log("LayerZero receiver peer set:");
        console.log("  receiver:", receiver);
        console.log("  srcEid  :", baseEid);
        console.log("  peer    :", baseCollector);
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
