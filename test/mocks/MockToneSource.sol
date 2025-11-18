// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockToneSource {
    string private constant SCRIPT = "<script>window.mockToneLoaded=true;</script>";

    function getTonejs() external pure returns (string memory) {
        return SCRIPT;
    }
}
