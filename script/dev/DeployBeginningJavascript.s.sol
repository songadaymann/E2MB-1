// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/// @notice Broadcasts the runtime bytecode for Dav's `beginningJS` contract.
///         Reads the bytecode payload from disk (defaults to the mainnet snapshot)
///         and deploys it verbatim using `CREATE`.
contract DeployBeginningJavascript is Script {
    function run() external {
        string memory path = vm.envOr(
            "BEGINNING_JS_BYTECODE_PATH",
            string("script/data/beginning_js_mainnet_code.hex")
        );
        bytes memory runtime = vm.readFileBinary(path);
        require(runtime.length != 0, "DeployBeginningJavascript: empty bytecode");

        vm.startBroadcast();
        address deployed;
        assembly {
            deployed := create(0, add(runtime, 0x20), mload(runtime))
        }
        require(deployed != address(0), "DeployBeginningJavascript: deploy failed");
        vm.stopBroadcast();

        console2.log("BeginningJS deployed at", deployed);
    }
}
