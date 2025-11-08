// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../IRenderTypes.sol";
import "./ILifeLens.sol";
import "./LifeLensInit.sol";
import "./LifeSVG.sol";

/**
 * @title LifeLensSvgRenderer
 * @notice Thin adapter that exposes the Life Lens SVG as an ICountdownRenderer-compatible contract.
 */
contract LifeLensSvgRenderer {
    LifeLensInit public immutable lifeLens;

    constructor(address _lifeLens) {
        require(_lifeLens != address(0), "LifeLensSvgRenderer: lens required");
        lifeLens = LifeLensInit(_lifeLens);
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        ILifeLens.LifeBoard memory board = lifeLens.board(ctx.tokenId);
        bytes[2] memory palette = lifeLens.colors();
        return LifeSVG.generateSVG(board, palette);
    }
}
