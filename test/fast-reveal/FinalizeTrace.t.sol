// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IFastReveal {
    function finalizeReveal(uint256 tokenId) external;
}

contract FinalizeTrace is Test {
    address constant FAST_REVEAL = 0xD6db20EE5DAE8d8756b753E86Baf887Ecb6987E4;
    address constant OWNER = 0xAd9fDaD276AB1A430fD03177A07350CD7C61E897;

    string private rpcUrl;
    bool private forkEnabled;

    function setUp() public {
        rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        forkEnabled = bytes(rpcUrl).length > 0;
        if (forkEnabled) {
            vm.createSelectFork(rpcUrl, 9453700);
        }
    }

    function testTraceFinalize() public {
        if (!forkEnabled) {
            return;
        }

        vm.startPrank(OWNER);
        IFastReveal(FAST_REVEAL).finalizeReveal(1);
        vm.stopPrank();
    }
}
