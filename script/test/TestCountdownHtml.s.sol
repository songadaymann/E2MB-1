// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/render/pre/CountdownHtmlRenderer.sol";
import "../../src/render/IRenderTypes.sol";

/**
 * @title TestCountdownHtml
 * @notice Generate HTML countdown and save both data URI and decoded HTML
 */
contract TestCountdownHtml is Script {
    
    function run() external {
        // Deploy the renderer
        CountdownHtmlRenderer renderer = new CountdownHtmlRenderer();
        
        // Create render context
        RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: 2026,
            closenessBps: 0,
            blocksDisplay: 23527793,
            seed: 12345,
            nowTs: block.timestamp
        });
        
        // Generate HTML data URI
        string memory dataUri = renderer.render(ctx);
        
        // Extract just the HTML by removing the data URI prefix
        // For testing, also generate plain HTML file
        string memory html = _extractHtml(ctx.blocksDisplay, ctx.nowTs);
        
        // Write files
        vm.writeFile("OUTPUTS/countdown-html-datauri.txt", dataUri);
        vm.writeFile("OUTPUTS/countdown.html", html);
        
        console.log("Generated:");
        console.log("  OUTPUTS/countdown-html-datauri.txt (for NFT metadata)");
        console.log("  OUTPUTS/countdown.html (open in browser to test)");
        console.log("Blocks display:", ctx.blocksDisplay);
        console.log("Start timestamp:", ctx.nowTs);
    }
    
    // Duplicate the HTML generation logic for testing
    function _extractHtml(uint256 blocksDisplay, uint256 nowTs) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8">',
            '<style>',
            'body{margin:0;background:#000;display:flex;align-items:center;justify-content:center;height:100vh;font-family:monospace}',
            '#container{text-align:center}',
            '#circle{width:560px;height:560px;border:2px solid #fff;border-radius:50%;position:relative;margin:20px auto}',
            '#grid{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);display:grid;grid-template-columns:repeat(4,60px);gap:40px 20px;color:#fff}',
            '.digit{font-size:72px;font-weight:bold;width:60px;text-align:center;font-variant-numeric:tabular-nums}',
            '#ball{width:24px;height:24px;background:#fff;border-radius:50%;position:absolute;top:0;left:50%;margin-left:-12px}',
            '</style></head><body><div id="container"><div id="circle"><div id="ball"></div><div id="grid">',
            '<div class="digit" id="d11">0</div><div class="digit" id="d10">0</div><div class="digit" id="d9">0</div><div class="digit" id="d8">0</div>',
            '<div class="digit" id="d7">0</div><div class="digit" id="d6">0</div><div class="digit" id="d5">0</div><div class="digit" id="d4">0</div>',
            '<div class="digit" id="d3">0</div><div class="digit" id="d2">0</div><div class="digit" id="d1">0</div><div class="digit" id="d0">0</div>',
            '</div></div></div><script>',
            'const START_BLOCKS=', _uint2str(blocksDisplay), ';',
            'const START_TIME=', _uint2str(nowTs), '*1000;',
            'const BLOCK_SECONDS=12;',
            'function update(){',
            'const elapsed=(Date.now()-START_TIME)/1000;',
            'const blocksElapsed=Math.floor(elapsed/BLOCK_SECONDS);',
            'const currentBlocks=Math.max(0,START_BLOCKS-blocksElapsed);',
            'const str=String(currentBlocks).padStart(12,"0");',
            'for(let i=0;i<12;i++){',
            'document.getElementById("d"+(11-i)).textContent=str[i];',
            '}',
            'const ballAngle=(elapsed%BLOCK_SECONDS)/BLOCK_SECONDS*360;',
            'const ballX=280+280*Math.sin(ballAngle*Math.PI/180);',
            'const ballY=280-280*Math.cos(ballAngle*Math.PI/180);',
            'const ball=document.getElementById("ball");',
            'ball.style.left=ballX+"px";',
            'ball.style.top=ballY+"px";',
            '}',
            'setInterval(update,50);update();',
            '</script></body></html>'
        ));
    }
    
    function _uint2str(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
