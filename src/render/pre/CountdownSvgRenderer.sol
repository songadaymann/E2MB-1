// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CountdownRenderer.sol";
import "../IRenderTypes.sol";

/**
 * @title CountdownSvgRenderer
 * @notice Thin wrapper that exposes the library countdown renderer as a deployable contract
 * @dev Implements the ICountdownRenderer interface expected by EveryTwoMillionBlocks
 */
contract CountdownSvgRenderer {
    function render(RenderTypes.RenderCtx memory ctx) external pure returns (string memory) {
        return CountdownRenderer.render(ctx);
    }
}
