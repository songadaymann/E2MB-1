// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title Step 4: Add Persistence Across Refreshes
 * @notice Use contract's nowTs instead of Date.now() so countdown continues correctly on refresh
 */
contract Step4_Persistence is Script {
    
    function run() external {
        uint256 startBlocks = 23527793;
        // Use current real timestamp for testing (Oct 2024)
        uint256 nowTs = 1729000000; // ~Oct 15, 2024
        
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8">',
            '<style>',
            'body{margin:0;background:#000;color:#fff;font-family:monospace;display:flex;align-items:center;justify-content:center;height:100vh;flex-direction:column}',
            '#container{position:relative;width:600px;height:600px}',
            '#circle{width:100%;height:100%;border:2px solid #fff;border-radius:50%;box-sizing:border-box;position:relative}',
            '#grid{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);display:grid;grid-template-columns:repeat(4,60px);gap:40px 30px}',
            '.digit{width:60px;height:80px}',
            '#ball{width:24px;height:24px;background:#fff;border-radius:50%;position:absolute;transition:left 0.05s linear,top 0.05s linear}',
            '#debug{margin-top:20px;font-size:14px;color:#666;text-align:center}',
            '</style></head><body>',
            '<div id="container">',
            '<div id="circle">',
            '<div id="ball"></div>',
            '<div id="grid">',
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
            '</div></div></div>',
            '<div id="debug">',
            '<div>Blocks: <span id="currentBlocks"></span> | Elapsed: <span id="elapsed"></span>s</div>',
            '<div>Contract time: ', _uint2str(nowTs), ' | Browser time: <span id="browserTime"></span></div>',
            '<div style="color:#0f0;margin-top:10px">Refresh the page - countdown should continue from same position!</div>',
            '</div>',
            '<script>',
            _digitPaths(),
            'const START_BLOCKS=', _uint2str(startBlocks), ';',
            'const CONTRACT_TIME=', _uint2str(nowTs), ';',
            'const BLOCK_SECONDS=12;',
            'const CENTER_X=300;',
            'const CENTER_Y=300;',
            'const RADIUS=299;',
            'const BALL_RADIUS=12;',
            'function renderDigit(value){return DIGITS[value];}',
            'function update(){',
            'const browserTimeMs=Date.now();',
            'const browserTimeSec=browserTimeMs/1000;',
            'const elapsedSec=browserTimeSec-CONTRACT_TIME;',
            'document.getElementById("browserTime").textContent=Math.floor(browserTimeSec);',
            'const blocksElapsed=Math.floor(elapsedSec/BLOCK_SECONDS);',
            'const currentBlocks=Math.max(0,START_BLOCKS-blocksElapsed);',
            'document.getElementById("elapsed").textContent=elapsedSec.toFixed(0);',
            'document.getElementById("currentBlocks").textContent=currentBlocks;',
            'const str=String(currentBlocks).padStart(12,"0");',
            'for(let i=0;i<12;i++){',
            'const digitValue=parseInt(str[i]);',
            'const digitIndex=11-i;',
            'document.getElementById("d"+digitIndex).innerHTML=renderDigit(digitValue);',
            '}',
            'const progress=(elapsedSec%BLOCK_SECONDS)/BLOCK_SECONDS;',
            'const angleDeg=progress*360;',
            'const angleRad=angleDeg*Math.PI/180;',
            'const ballX=CENTER_X+RADIUS*Math.sin(angleRad)-BALL_RADIUS;',
            'const ballY=CENTER_Y-RADIUS*Math.cos(angleRad)-BALL_RADIUS;',
            'const ball=document.getElementById("ball");',
            'ball.style.left=ballX+"px";',
            'ball.style.top=ballY+"px";',
            '}',
            'setInterval(update,50);',
            'update();',
            '</script></body></html>'
        ));
        
        vm.writeFile("OUTPUTS/html-countdown-step4.html", html);
        console.log("Generated: OUTPUTS/html-countdown-step4.html");
        console.log("Contract timestamp:", nowTs);
        console.log("Start blocks:", startBlocks);
        console.log("");
        console.log("TEST: Open the page, note the position, then refresh.");
        console.log("The countdown should continue from the SAME position!");
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
}
