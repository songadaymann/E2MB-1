// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Base64.sol";

import "../../IRenderTypes.sol";
import "./ILifeLens.sol";
import "./LifeLensInit.sol";
import "./LifeSVG.sol";
import "./LifeScript.sol";

/**
 * @title LifeLensHtmlRenderer
 * @notice Returns the Life Lens HTML payload as a data URI for animation_url usage.
 */
contract LifeLensHtmlRenderer {
    LifeLensInit public immutable lifeLens;

    constructor(address _lifeLens) {
        require(_lifeLens != address(0), "LifeLensHtmlRenderer: lens required");
        lifeLens = LifeLensInit(_lifeLens);
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        ILifeLens.LifeBoard memory board = lifeLens.board(ctx.tokenId);
        bytes[2] memory palette = lifeLens.colors();

        string memory svg = LifeSVG.generateSVG(board, palette);
        string memory script = LifeScript.generateScript(board, lifeLens.name());

        string memory html = Base64.encode(
            abi.encodePacked(
                "<!DOCTYPE html><html><head><meta charset='utf-8'/>",
                "<style>body{background:",
                palette[0],
                ";display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;font-family:monospace;color:",
                palette[1],
                ";}#life-container{display:flex;align-items:center;justify-content:center;width:100%;}svg{max-width:min(90vw,640px);height:auto;}</style></head><body><div id='life-container'>",
                svg,
                "</div><script>",
                script,
                "</script></body></html>"
            )
        );

        return string(abi.encodePacked("data:text/html;base64,", html));
    }
}
