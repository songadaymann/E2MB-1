// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title Step 2: Add 7-Segment Digit Display
 * @notice Replace plain numbers with SVG 7-segment digits
 */
contract Step2_SevenSegment is Script {
    
    function run() external {
        uint256 startBlocks = 23527793;
        
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8">',
            '<style>',
            'body{background:#000;color:#fff;font-family:monospace;padding:50px}',
            '#grid{display:grid;grid-template-columns:repeat(4,60px);gap:40px 30px;width:fit-content}',
            '.digit{width:60px;height:80px}',
            '#debug{margin-top:20px;font-size:16px;color:#666}',
            '</style></head><body>',
            '<h3>Step 2: Seven-Segment Digits</h3>',
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
            '</div>',
            '<div id="debug">',
            '<div>Start blocks: ', _uint2str(startBlocks), '</div>',
            '<div>Current blocks: <span id="currentBlocks"></span></div>',
            '<div>Elapsed time: <span id="elapsed"></span>s</div>',
            '</div>',
            '<script>',
            _digitPaths(),
            'const START_BLOCKS=', _uint2str(startBlocks), ';',
            'const START_TIME=Date.now();',
            'const BLOCK_SECONDS=12;',
            'function renderDigit(value){',
            'return DIGITS[value];',
            '}',
            'function update(){',
            'const elapsedSec=(Date.now()-START_TIME)/1000;',
            'const blocksElapsed=Math.floor(elapsedSec/BLOCK_SECONDS);',
            'const currentBlocks=Math.max(0,START_BLOCKS-blocksElapsed);',
            'document.getElementById("elapsed").textContent=elapsedSec.toFixed(1);',
            'document.getElementById("currentBlocks").textContent=currentBlocks;',
            'const str=String(currentBlocks).padStart(12,"0");',
            'for(let i=0;i<12;i++){',
            'const digitValue=parseInt(str[i]);',
            'const digitIndex=11-i;',
            'document.getElementById("d"+digitIndex).innerHTML=renderDigit(digitValue);',
            '}',
            '}',
            'setInterval(update,100);',
            'update();',
            '</script></body></html>'
        ));
        
        vm.writeFile("OUTPUTS/html-countdown-step2.html", html);
        console.log("Generated: OUTPUTS/html-countdown-step2.html");
        console.log("Should show 7-segment digits counting down");
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
