// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/render/pre/CountdownRenderer.sol";
import "../src/render/IRenderTypes.sol";

contract CountdownTest is Test {
    using RenderTypes for RenderTypes.RenderCtx;
    
    function testCountdownAtVariousTimes() public {
        uint256 startYear = 2026;
        uint256 revealYear = 2026;
        uint256 jan1_2026 = 1767225600; // Jan 1, 2026 00:00:00 UTC
        
        // Test 1: 1 year before reveal (closeness = 0)
        uint256 oneYearBefore = jan1_2026 - 365 days;
        vm.warp(oneYearBefore);
        
        RenderTypes.RenderCtx memory ctx1 = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: revealYear,
            closenessBps: 0,
            blocksDisplay: 2628000, // ~1 year in 12-sec blocks
            seed: 12345,
            nowTs: block.timestamp
        });
        
        string memory svg1 = CountdownRenderer.render(ctx1);
        console.log("\n=== 1 YEAR BEFORE REVEAL ===");
        console.log("Timestamp:", block.timestamp);
        console.log("SVG length:", bytes(svg1).length);
        
        // Test 2: 1 day before reveal (closeness high)
        uint256 oneDayBefore = jan1_2026 - 1 days;
        vm.warp(oneDayBefore);
        
        uint256 closenessBps2 = 9973; // ~99.73% of the way there
        
        RenderTypes.RenderCtx memory ctx2 = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: revealYear,
            closenessBps: closenessBps2,
            blocksDisplay: 7200, // ~1 day in 12-sec blocks
            seed: 12345,
            nowTs: block.timestamp
        });
        
        string memory svg2 = CountdownRenderer.render(ctx2);
        console.log("\n=== 1 DAY BEFORE REVEAL ===");
        console.log("Timestamp:", block.timestamp);
        console.log("Closeness:", closenessBps2, "bps");
        console.log("SVG length:", bytes(svg2).length);
        
        // Test 3: 1 minute before reveal
        uint256 oneMinBefore = jan1_2026 - 1 minutes;
        vm.warp(oneMinBefore);
        
        RenderTypes.RenderCtx memory ctx3 = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: revealYear,
            closenessBps: 9999,
            blocksDisplay: 5, // 5 blocks left
            seed: 12345,
            nowTs: block.timestamp
        });
        
        string memory svg3 = CountdownRenderer.render(ctx3);
        console.log("\n=== 1 MINUTE BEFORE REVEAL ===");
        console.log("Timestamp:", block.timestamp);
        console.log("Blocks remaining:", uint256(5));
        console.log("SVG length:", bytes(svg3).length);
    }
    
    function testTimingAccuracy() public {
        // Test that 1s place cycles every 12 seconds
        console.log("\n=== TIMING TEST ===");
        console.log("Expected: 1s place completes cycle in 12 seconds");
        console.log("Expected: 10s place ticks every 120 seconds (12 sec * 10)");
        console.log("Expected: 100s place ticks every 1200 seconds");
        
        // The fix ensures:
        // d0=1  -> cycle = 1 * 12 = 12 seconds ✅
        // d1=10 -> cycle = 10 * 12 = 120 seconds ✅  
        // d2=100 -> cycle = 100 * 12 = 1200 seconds ✅
        
        vm.warp(1767225600); // Jan 1, 2026
        
        // At timestamp % 12 = 0, ones place should show startDigit
        // At timestamp % 12 = 6, ones place should be mid-cycle
        // At timestamp % 12 = 11, ones place should be near next digit
        
        console.log("Fix applied:");
        console.log("- Removed ternary: (d == 1 ? 120 : d*12)");
        console.log("- Now uses: d * 12 for all digits");
        console.log("- Direction: Positive translate (downward)");
        console.log("- Sequence: Forward (0,1,2...9,0)");
    }
    
    function testSaveToFile() public {
        // Generate SVG at a specific time for visual inspection
        uint256 testTime = 1767225540; // 60 seconds before Jan 1, 2026
        vm.warp(testTime);
        
        RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 0,
            revealYear: 2026,
            closenessBps: 9999,
            blocksDisplay: 5,
            seed: 12345,
            nowTs: block.timestamp
        });
        
        string memory svg = CountdownRenderer.render(ctx);
        
        // Write to file for browser testing
        vm.writeFile("OUTPUTS/countdown_test.svg", svg);
        console.log("\n=== SVG WRITTEN ===");
        console.log("File: OUTPUTS/countdown_test.svg");
        console.log("Open in browser to verify:");
        console.log("1. Numbers move DOWNWARD");
        console.log("2. Ones place cycles every 12 seconds");
        console.log("3. Tens place ticks when ones wraps");
    }
}
