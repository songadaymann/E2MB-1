// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library VRFV2PlusClient {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    struct ExtraArgsV1 {
        bool nativePayment;
    }

    uint16 private constant EXTRA_ARGS_VERSION = 1;

    function _argsToBytes(ExtraArgsV1 memory extraArgs) internal pure returns (bytes memory) {
        return abi.encodePacked(EXTRA_ARGS_VERSION, abi.encode(extraArgs));
    }
}
