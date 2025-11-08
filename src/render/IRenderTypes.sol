// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library RenderTypes {
    struct RenderCtx {
        uint256 tokenId;
        uint256 rank;
        uint256 revealYear;
        uint256 closenessBps; // 0..10000
        uint256 blocksDisplay; // countdown display units (blocks)
        uint32 seed;
        uint256 nowTs;
    }
}
