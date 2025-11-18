// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CountdownRenderer.sol";
import "../IRenderTypes.sol";

contract CountdownSvgRenderer {
    function render(RenderTypes.RenderCtx memory ctx) external pure returns (string memory) {
        return CountdownRenderer.render(ctx);
    }
}
