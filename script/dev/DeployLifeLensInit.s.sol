// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/interfaces/ISongAlgorithm.sol";

contract DeployLifeLensInit is Script {
    function run() external {
        address msong = vm.envAddress("MSONG_ADDRESS");
        address songAlgorithm = vm.envAddress("SONG_ALGORITHM_ADDRESS");

        vm.startBroadcast();
        LifeLensInit init = new LifeLensInit(
            msong,
            ILifeSeedSource(msong),
            ISongAlgorithm(songAlgorithm)
        );
        vm.stopBroadcast();

        console2.log("LifeLensInit deployed at", address(init));
    }
}
