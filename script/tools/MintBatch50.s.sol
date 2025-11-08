// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";

contract MintBatch50 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address recipient = vm.envOr("MINT_TO", vm.addr(deployerKey));
        EveryTwoMillionBlocks nft = EveryTwoMillionBlocks(
            vm.envAddress("MSONG_ADDRESS")
        );

        vm.startBroadcast(deployerKey);
        for (uint32 i = 0; i < 50; ++i) {
            nft.mint(recipient, 0); // pass 0 to have the contract auto-seed
        }
        vm.stopBroadcast();
    }
}
