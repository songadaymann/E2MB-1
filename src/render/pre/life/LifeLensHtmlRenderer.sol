// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Base64.sol";

import "../../IRenderTypes.sol";
import "./ILifeLens.sol";
import "./LifeLensInit.sol";
import "./LifeSVG.sol";
import "./LifeScript.sol";
import "../../../interfaces/external/ILifeGlyphFontSource.sol";

contract LifeLensHtmlRenderer {
    LifeLensInit public immutable lifeLens;
    ILifeGlyphFontSource public immutable fontSource;

    constructor(address _lifeLens, address _fontSource) {
        require(_lifeLens != address(0), "LifeLensHtmlRenderer: lens required");
        require(_fontSource != address(0), "LifeLensHtmlRenderer: font source required");
        lifeLens = LifeLensInit(_lifeLens);
        fontSource = ILifeGlyphFontSource(_fontSource);
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        ILifeLens.LifeBoard memory board = lifeLens.board(ctx.tokenId);
        bytes[2] memory palette = lifeLens.colors();

        string memory svg = LifeSVG.generateSVG(board, palette);
        string memory script = LifeScript.generateScript(board, lifeLens.name());

        string memory html = Base64.encode(
            abi.encodePacked(
                "<!DOCTYPE html><html><head><meta charset='utf-8'/>",
                "<style>",
                fontSource.fontFaceCSS(),
                ":root{--life-size:min(95vmin,640px);}",
                "html,body{margin:0;height:100%;width:100%;}",
                "body{background:",
                palette[0],
                ";display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:monospace;color:",
                palette[1],
                ";}",
                "#life-container{display:flex;align-items:center;justify-content:center;width:var(--life-size);height:var(--life-size);}",
                "svg{width:var(--life-size);height:var(--life-size);}",
                "</style></head><body><div id='life-container'>",
                svg,
                "</div><script>",
                script,
                "</script></body></html>"
            )
        );

        return string(abi.encodePacked("data:text/html;base64,", html));
    }
}
