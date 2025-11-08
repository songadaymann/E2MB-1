// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IBaseBurnCollector {
    function quoteCheckpoint(uint256[] calldata tokenIds) external view returns (uint256 nativeFee, uint256 lzTokenFee);
    function checkpoint(uint256[] calldata tokenIds) external payable returns (bytes32 guid, uint64 nonce, uint256 feePaid);
}

contract BaseCheckpoint is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address collector = vm.envAddress("BASE_BURN_COLLECTOR_ADDRESS");

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 8;
        tokenIds[2] = 9;

        IBaseBurnCollector baseCollector = IBaseBurnCollector(collector);
        (uint256 nativeFee, ) = baseCollector.quoteCheckpoint(tokenIds);

        console.log("quoteCheckpoint native fee:");
        console.logUint(nativeFee);

        vm.startBroadcast(deployerKey);
        (bytes32 guid, uint64 nonce, uint256 feePaid) = baseCollector.checkpoint{value: nativeFee}(tokenIds);
        vm.stopBroadcast();

        console.log("checkpoint sent");
        console.logBytes32(guid);
        console.logUint(nonce);
        console.logUint(feePaid);
    }
}
