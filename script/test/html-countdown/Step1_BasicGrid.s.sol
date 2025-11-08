// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title Step 1: Basic Grid with Numbers
 * @notice Just 12 digits counting down, no styling, verify the JavaScript logic works
 */
contract Step1_BasicGrid is Script {
    
    function run() external {
        uint256 startBlocks = 23527793;
        uint256 startTime = block.timestamp;
        
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8">',
            '<style>',
            'body{background:#000;color:#fff;font-family:monospace;padding:50px;font-size:24px}',
            '#grid{display:grid;grid-template-columns:repeat(4,80px);gap:20px;width:fit-content}',
            '.digit{font-size:72px;text-align:center;border:1px solid #333}',
            '#debug{margin-top:20px;font-size:16px;color:#666}',
            '</style></head><body>',
            '<h3>Step 1: Basic Grid Test</h3>',
            '<div id="grid">',
            '<div class="digit" id="d11">0</div><div class="digit" id="d10">0</div><div class="digit" id="d9">0</div><div class="digit" id="d8">0</div>',
            '<div class="digit" id="d7">0</div><div class="digit" id="d6">0</div><div class="digit" id="d5">0</div><div class="digit" id="d4">0</div>',
            '<div class="digit" id="d3">0</div><div class="digit" id="d2">0</div><div class="digit" id="d1">0</div><div class="digit" id="d0">0</div>',
            '</div>',
            '<div id="debug">',
            '<div>Start blocks: <span id="startBlocks"></span></div>',
            '<div>Current blocks: <span id="currentBlocks"></span></div>',
            '<div>Elapsed time: <span id="elapsed"></span>s</div>',
            '<div>Blocks elapsed: <span id="blocksElapsed"></span></div>',
            '</div>',
            '<script>',
            'const START_BLOCKS=', _uint2str(startBlocks), ';',
            'const START_TIME=Date.now();',
            'const BLOCK_SECONDS=12;',
            'document.getElementById("startBlocks").textContent=START_BLOCKS;',
            'function update(){',
            'const now=Date.now();',
            'const elapsedMs=now-START_TIME;',
            'const elapsedSec=elapsedMs/1000;',
            'const blocksElapsed=Math.floor(elapsedSec/BLOCK_SECONDS);',
            'const currentBlocks=Math.max(0,START_BLOCKS-blocksElapsed);',
            'document.getElementById("elapsed").textContent=elapsedSec.toFixed(1);',
            'document.getElementById("blocksElapsed").textContent=blocksElapsed;',
            'document.getElementById("currentBlocks").textContent=currentBlocks;',
            'const str=String(currentBlocks).padStart(12,"0");',
            'for(let i=0;i<12;i++){',
            'const digitIndex=11-i;',
            'document.getElementById("d"+digitIndex).textContent=str[i];',
            '}',
            '}',
            'setInterval(update,100);',
            'update();',
            '</script></body></html>'
        ));
        
        vm.writeFile("OUTPUTS/html-countdown-step1.html", html);
        console.log("Generated: OUTPUTS/html-countdown-step1.html");
        console.log("Open in browser - numbers should count down every 12 seconds");
        console.log("Start blocks:", startBlocks);
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
