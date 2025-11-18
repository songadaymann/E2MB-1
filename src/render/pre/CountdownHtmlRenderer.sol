// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IRenderTypes.sol";

contract CountdownHtmlRenderer {
    
    function render(RenderTypes.RenderCtx memory ctx) external pure returns (string memory) {
        return _generateHtml(ctx.blocksDisplay, ctx.nowTs);
    }
    
    function _generateHtml(uint256 blocksDisplay, uint256 nowTs) private pure returns (string memory) {
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8">',
            '<style>',
            'html,body{margin:0;height:100%;width:100%;background:#000;color:#fff;font-family:monospace;display:flex;align-items:center;justify-content:center}',
            '#frame{position:relative;width:100vw;height:100vh;max-width:600px;max-height:600px}',
            '#container{position:absolute;top:50%;left:50%;width:600px;height:600px;transform:translate(-50%,-50%);transform-origin:50% 50%;}',
            '#circle{width:100%;height:100%;border:2px solid #fff;border-radius:50%;box-sizing:border-box;position:relative}',
            '#grid{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);display:grid;grid-template-columns:repeat(4,60px);gap:40px 30px}',
            '.digit{width:60px;height:80px}',
            '#ball{width:24px;height:24px;background:#fff;border-radius:50%;position:absolute;transition:left 0.05s linear,top 0.05s linear}',
            '</style></head><body>',
            '<div id="frame"><div id="container"><div id="circle"><div id="ball"></div><div id="grid">',
            '<svg class="digit" id="d11" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d10" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d9" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d8" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d7" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d6" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d5" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d4" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d3" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d2" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d1" viewBox="0 0 48 80"></svg>',
            '<svg class="digit" id="d0" viewBox="0 0 48 80"></svg>',
            '</div></div></div></div><script>',
            _digitPaths(),
            'const START_BLOCKS=', _uint2str(blocksDisplay), ';',
            'const CONTRACT_TIME=', _uint2str(nowTs), ';',
            'const BLOCK_SECONDS=12;',
            'const CENTER_X=300;',
            'const CENTER_Y=300;',
            'const RADIUS=299;',
            'const BALL_RADIUS=12;',
            'const frame=document.getElementById("frame");',
            'const container=document.getElementById("container");',
            'function renderDigit(v){return DIGITS[v];}',
            'function resize(){',
            'const size=Math.min(window.innerWidth,window.innerHeight,600);',
            'frame.style.width=size+"px";',
            'frame.style.height=size+"px";',
            'const scale=size/600;',
            'container.style.transform=`translate(-50%,-50%) scale(${scale})`;',
            '}',
            'function update(){',
            'const elapsedSec=Date.now()/1000-CONTRACT_TIME;',
            'const blocksElapsed=Math.floor(elapsedSec/BLOCK_SECONDS);',
            'const currentBlocks=Math.max(0,START_BLOCKS-blocksElapsed);',
            'const str=String(currentBlocks).padStart(12,"0");',
            'for(let i=0;i<12;i++){',
            'document.getElementById("d"+(11-i)).innerHTML=renderDigit(parseInt(str[i]));',
            '}',
            'const progress=(elapsedSec%BLOCK_SECONDS)/BLOCK_SECONDS;',
            'const angleRad=progress*2*Math.PI;',
            'const ballX=CENTER_X+RADIUS*Math.sin(angleRad)-BALL_RADIUS;',
            'const ballY=CENTER_Y-RADIUS*Math.cos(angleRad)-BALL_RADIUS;',
            'const ball=document.getElementById("ball");',
            'ball.style.left=ballX+"px";',
            'ball.style.top=ballY+"px";',
            '}',
            'window.addEventListener("resize",resize);',
            'resize();',
            'setInterval(update,50);update();',
            '</script></body></html>'
        ));
        
        return string(abi.encodePacked(
            'data:text/html;base64,',
            _base64Encode(bytes(html))
        ));
    }
    
    function _digitPaths() private pure returns (string memory) {
        return string(abi.encodePacked(
            'const DIGITS={',
            '0:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '1:\'<g transform="translate(8,0)" fill="#fff"><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>\',',
            '2:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '3:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '4:\'<g transform="translate(8,0)" fill="#fff"><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>\',',
            '5:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '6:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '7:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>\',',
            '8:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\',',
            '9:\'<g transform="translate(8,0)" fill="#fff"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>\'',
            '};'
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
    
    function _base64Encode(bytes memory data) private pure returns (string memory) {
        bytes memory alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 len = data.length;
        if (len == 0) return "";
        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        uint256 i = 0;
        uint256 j = 0;
        
        while (i < len) {
            uint256 a = i < len ? uint8(data[i++]) : 0;
            uint256 b = i < len ? uint8(data[i++]) : 0;
            uint256 c = i < len ? uint8(data[i++]) : 0;
            uint256 triple = (a << 16) + (b << 8) + c;
            result[j++] = alphabet[(triple >> 18) & 63];
            result[j++] = alphabet[(triple >> 12) & 63];
            result[j++] = i > len + 1 ? bytes1('=') : alphabet[(triple >> 6) & 63];
            result[j++] = i > len ? bytes1('=') : alphabet[triple & 63];
        }
        
        return string(result);
    }
}
