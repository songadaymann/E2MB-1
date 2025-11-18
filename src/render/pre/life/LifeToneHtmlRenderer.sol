// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Base64.sol";

import "../../IRenderTypes.sol";
import "../../../interfaces/external/IBeginningJavascript.sol";
import "./ILifeLens.sol";
import "./LifeLensInit.sol";
import "./LifeSVG.sol";
import "./LifeToneScript.sol";
import "../../../interfaces/external/ILifeGlyphFontSource.sol";

contract LifeToneHtmlRenderer {
    LifeLensInit public immutable lifeLens;
    IBeginningJavascript public immutable toneSource;
    ILifeGlyphFontSource public immutable fontSource;

    constructor(address _lifeLens, address _toneSource, address _fontSource) {
        require(_lifeLens != address(0), "LifeToneHtmlRenderer: lens required");
        require(_toneSource != address(0), "LifeToneHtmlRenderer: tone source required");
        require(_fontSource != address(0), "LifeToneHtmlRenderer: font source required");
        lifeLens = LifeLensInit(_lifeLens);
        toneSource = IBeginningJavascript(_toneSource);
        fontSource = ILifeGlyphFontSource(_fontSource);
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        ILifeLens.LifeBoard memory board = lifeLens.board(ctx.tokenId);
        bytes[2] memory palette = lifeLens.colors();

        string memory svg = LifeSVG.generateSVG(board, palette);
        string memory script = LifeToneScript.generateScript(board, lifeLens.name());
        string memory toneScripts = toneSource.getTonejs();

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
                "#life-shell{width:var(--life-size);height:var(--life-size);max-width:var(--life-size);max-height:var(--life-size);}",
                "#life-container{position:relative;width:100%;height:100%;}",
                "svg{width:100%;height:100%;display:block;}",
                "#life-overlay{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;padding:16px;text-align:center;background:rgba(0,0,0,0.72);color:",
                palette[1],
                ";font-size:18px;letter-spacing:1px;text-transform:uppercase;font-weight:600;cursor:pointer;transition:opacity 0.25s ease;}",
                "#life-overlay.overlay-hidden{opacity:0;pointer-events:none;}",
                "#life-title{display:none;}",
                "</style>",
                toneScripts,
                "</head><body><div id='life-shell'><div id='life-container'>",
                svg,
                "<div id='life-overlay'>Tap to start audio</div>",
                "</div><div id='life-title'></div></div><script>",
                script,
                "</script></body></html>"
            )
        );

        return string(abi.encodePacked("data:text/html;base64,", html));
    }
}
