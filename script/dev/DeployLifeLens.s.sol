// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/render/pre/life/LifeLensRenderer.sol";
contract DeployLifeLens is Script {
    function run() external {
        address msongAddress = vm.envAddress("MSONG_ADDRESS");
        address songAlgorithmAddress = vm.envAddress("SONG_ALGORITHM_ADDRESS");

        vm.startBroadcast();

        LifeLensInit lens = new LifeLensInit(
            msongAddress,
            ILifeSeedSource(msongAddress),
            ISongAlgorithm(songAlgorithmAddress)
        );

        LifeLensRenderer renderer = new LifeLensRenderer(msongAddress, address(lens));

        vm.stopBroadcast();

        console2.log("LifeLensInit deployed at", address(lens));
        console2.log("LifeLensRenderer deployed at", address(renderer));
    }
}
