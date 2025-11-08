// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/render/pre/CountdownRenderer.sol";
import "../../src/render/IRenderTypes.sol";

/**
 * @title GenerateCountdownSVG
 * @notice Generate test countdown SVG for browser inspection
 */
contract GenerateCountdownSVG is Script {
    using RenderTypes for RenderTypes.RenderCtx;
    
    function run() external {
        // Test scenario: 123 blocks remaining (about 24 minutes)
        // This will show:
        // - Top row: 0000
        // - Middle row: 0000  
        // - Bottom row: 0123
        
        uint256 testTime = block.timestamp;
        
        RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: 2026,
            closenessBps: 5000, // 50% of the way there (gray background)
            blocksDisplay: 123,
            seed: 12345,
            nowTs: testTime
        });
        
        string memory svg = CountdownRenderer.render(ctx);
        
        // Wrap in HTML for easy browser testing
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html>\n',
            '<html>\n',
            '<head>\n',
            '  <meta charset="UTF-8">\n',
            '  <title>Countdown Test - Fixed Version</title>\n',
            '  <style>\n',
            '    body { margin: 40px; font-family: monospace; background: #111; color: #fff; }\n',
            '    .container { max-width: 800px; margin: 0 auto; }\n',
            '    svg { border: 2px solid #333; background: white; }\n',
            '    .info { background: #222; padding: 20px; margin: 20px 0; border-radius: 8px; }\n',
            '    .check { color: #0f0; }\n',
            '    h2 { color: #0ff; }\n',
            '  </style>\n',
            '</head>\n',
            '<body>\n',
            '  <div class="container">\n',
            '    <h1>Countdown Timer - Fixed Version</h1>\n',
            '    \n',
            '    <div class="info">\n',
            '      <h2>What to Check:</h2>\n',
            '      <p><span class="check">[OK]</span> Numbers should move <strong>DOWNWARD</strong> (not upward)</p>\n',
            '      <p><span class="check">[OK]</span> Ones place (rightmost) should cycle every <strong>12 seconds</strong></p>\n',
            '      <p><span class="check">[OK]</span> When ones place wraps from 9-&gt;0, tens place should <strong>tick up</strong></p>\n',
            '      <p><span class="check">[OK]</span> Year "2026" should be displayed at bottom</p>\n',
            '      <p><span class="check">[OK]</span> Current display: <strong>000 000 000 123</strong> (123 blocks)</p>\n',
            '    </div>\n',
            '    \n',
            '    <div style="background: white; padding: 20px; border-radius: 8px;">\n',
            '      ', svg, '\n',
            '    </div>\n',
            '    \n',
            '    <div class="info">\n',
            '      <h2>Technical Details:</h2>\n',
            '      <p>Timestamp: ', vm.toString(testTime), '</p>\n',
            '      <p>Blocks Display: 123</p>\n',
            '      <p>Closeness: 50% (5000 bps)</p>\n',
            '      <p>Animation Direction: DOWNWARD (positive translate)</p>\n',
            '      <p>Sequence Order: FORWARD (0,1,2...9,0)</p>\n',
            '      <p>Timing: d * 12 seconds (1s=12sec, 10s=120sec)</p>\n',
            '    </div>\n',
            '  </div>\n',
            '</body>\n',
            '</html>'
        ));
        
        // Write to file
        vm.writeFile("OUTPUTS/countdown_test.html", html);
        
        console.log("\n=== COUNTDOWN SVG GENERATED ===");
        console.log("File: OUTPUTS/countdown_test.html");
        console.log("\nOpen in browser:");
        console.log("  open OUTPUTS/countdown_test.html");
        console.log("\nWhat to verify:");
        console.log("  1. Numbers move DOWNWARD (intuitive)");
        console.log("  2. Ones place cycles every 12 seconds");
        console.log("  3. Tens place ticks when ones wraps");
        console.log("\nCurrent display: 000 000 000 123");
        console.log("Watch the '3' in ones place animate down to '4' over 12 seconds");
    }
}
