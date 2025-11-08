// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IOpLayerZeroReceiver {
    function setTrustedPeer(uint32 srcEid, bytes32 peer) external;
}

contract ConfigureOpReceiver is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address receiver = vm.envAddress("OP_L1_LAYERZERO_RECEIVER_ADDRESS");
        uint32 opEid = uint32(vm.envUint("OP_LAYERZERO_EID"));
        address opCollector = vm.envAddress("OP_BURN_COLLECTOR_ADDRESS");

        vm.startBroadcast(deployerKey);
        IOpLayerZeroReceiver(receiver).setTrustedPeer(opEid, _toBytes32(opCollector));
        vm.stopBroadcast();

        console.log("LayerZero OP receiver peer set:");
        console.log("  receiver:", receiver);
        console.log("  srcEid  :", opEid);
        console.log("  peer    :", opCollector);
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
