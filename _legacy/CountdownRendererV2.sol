// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IRenderTypes.sol";

/**
 * @title CountdownRendererV2
 * @notice Renders animated countdown with 12 flipping digits + ball progress indicator
 * @dev All animations sync to block.timestamp so they persist across page refreshes
 */
contract CountdownRendererV2 {
    
    uint256 private constant BASE = 12; // 12 seconds per block (Ethereum avg)
    
    /**
     * @notice Render the countdown SVG
     * @param ctx Render context with blocksDisplay and nowTs
     * @return SVG string
     */
    function render(RenderTypes.RenderCtx memory ctx) external pure returns (string memory) {
        return _generateSVG(ctx.nowTs, ctx.blocksDisplay);
    }
    
    function _generateSVG(uint256 nowTs, uint256 blocksDisplay) private pure returns (string memory) {
        // Grid setup - 3 rows × 4 columns = 12 digits
        uint256 spacing = 100;
        uint256 gridWidth = 3 * spacing;
        uint256 gridHeight = 2 * 120;
        uint256 startX = 300 - (gridWidth / 2);
        uint256 startY = 300 - (gridHeight / 2);
        
        // Circle setup
        uint256 circleRadius = 280;
        uint256 circleCenterX = 300;
        uint256 circleCenterY = 300;
        uint256 ballRadius = 12;
        
        // Ball animation timing (completes circle every BASE seconds)
        uint256 secondsIntoBall = nowTs % BASE;
        uint256 ballTimeRemaining = BASE - secondsIntoBall;
        
        // Animation parameters
        uint256 digitSpacing = 80; // Match digit height
        
        // Calculate animation params for all 12 places
        // Extract actual digits from blocksDisplay
        uint256 d0 = (blocksDisplay / 1) % 10;
        uint256 d1 = (blocksDisplay / 10) % 10;
        uint256 d2 = (blocksDisplay / 100) % 10;
        uint256 d3 = (blocksDisplay / 1000) % 10;
        uint256 d4 = (blocksDisplay / 10000) % 10;
        uint256 d5 = (blocksDisplay / 100000) % 10;
        uint256 d6 = (blocksDisplay / 1000000) % 10;
        uint256 d7 = (blocksDisplay / 10000000) % 10;
        uint256 d8 = (blocksDisplay / 100000000) % 10;
        uint256 d9 = (blocksDisplay / 1000000000) % 10;
        uint256 d10 = (blocksDisplay / 10000000000) % 10;
        uint256 d11 = (blocksDisplay / 100000000000) % 10;
        
        // Place 0 (ones): Show actual digit, animate from there
        uint256 cycle1 = BASE * 10;
        uint256 secondsIntoCycle1 = nowTs % cycle1;
        uint256 secondsOffset = secondsIntoCycle1 % BASE; // Position within current digit
        int256 p0BaseOffset = -int256(digitSpacing * (9 - d0)); // Start at actual digit
        int256 p0BeginPhase = -int256(secondsOffset); // Sync timing
        uint256 p0X = startX + (3 * spacing) - 24;
        uint256 p0Y = startY + ((2 - 0) * 120) - 40;
        
        // Place 1 (tens) - sync to its own cycle
        uint256 cycle2 = BASE * 100;
        uint256 secondsIntoCycle2 = nowTs % cycle2;
        int256 p1BaseOffset = -int256(digitSpacing * (9 - d1));
        int256 p1BeginPhase = -int256(secondsIntoCycle2 % (BASE * 10));
        uint256 p1X = startX + (2 * spacing) - 24;
        uint256 p1Y = startY + ((2 - 0) * 120) - 40;
        
        // Place 2 (hundreds) - sync to its own cycle
        uint256 cycle3 = BASE * 1000;
        uint256 secondsIntoCycle3 = nowTs % cycle3;
        int256 p2BaseOffset = -int256(digitSpacing * (9 - d2));
        int256 p2BeginPhase = -int256(secondsIntoCycle3 % (BASE * 100));
        uint256 p2X = startX + (1 * spacing) - 24;
        uint256 p2Y = startY + ((2 - 0) * 120) - 40;
        
        // Place 3 (thousands) - sync to its own cycle
        uint256 cycle4 = BASE * 10000;
        uint256 secondsIntoCycle4 = nowTs % cycle4;
        int256 p3BaseOffset = -int256(digitSpacing * (9 - d3));
        int256 p3BeginPhase = -int256(secondsIntoCycle4 % (BASE * 1000));
        uint256 p3X = startX + (0 * spacing) - 24;
        uint256 p3Y = startY + ((2 - 0) * 120) - 40;
        
        // Place 4 (ten thousands) - sync to its own cycle
        uint256 cycle5 = BASE * 100000;
        uint256 secondsIntoCycle5 = nowTs % cycle5;
        int256 p4BaseOffset = -int256(digitSpacing * (9 - d4));
        int256 p4BeginPhase = -int256(secondsIntoCycle5 % (BASE * 10000));
        uint256 p4X = startX + (3 * spacing) - 24;
        uint256 p4Y = startY + ((2 - 1) * 120) - 40;
        
        // Place 5 (hundred thousands) - sync to its own cycle
        uint256 cycle6 = BASE * 1000000;
        uint256 secondsIntoCycle6 = nowTs % cycle6;
        int256 p5BaseOffset = -int256(digitSpacing * (9 - d5));
        int256 p5BeginPhase = -int256(secondsIntoCycle6 % (BASE * 100000));
        uint256 p5X = startX + (2 * spacing) - 24;
        uint256 p5Y = startY + ((2 - 1) * 120) - 40;
        
        // Place 6 (millions) - sync to its own cycle
        uint256 cycle7 = BASE * 10000000;
        uint256 secondsIntoCycle7 = nowTs % cycle7;
        int256 p6BaseOffset = -int256(digitSpacing * (9 - d6));
        int256 p6BeginPhase = -int256(secondsIntoCycle7 % (BASE * 1000000));
        uint256 p6X = startX + (1 * spacing) - 24;
        uint256 p6Y = startY + ((2 - 1) * 120) - 40;
        
        // Place 7 (ten millions) - sync to its own cycle
        uint256 cycle8 = BASE * 100000000;
        uint256 secondsIntoCycle8 = nowTs % cycle8;
        int256 p7BaseOffset = -int256(digitSpacing * (9 - d7));
        int256 p7BeginPhase = -int256(secondsIntoCycle8 % (BASE * 10000000));
        uint256 p7X = startX + (0 * spacing) - 24;
        uint256 p7Y = startY + ((2 - 1) * 120) - 40;
        
        // Place 8 (hundred millions) - sync to its own cycle
        uint256 cycle9 = BASE * 1000000000;
        uint256 secondsIntoCycle9 = nowTs % cycle9;
        int256 p8BaseOffset = -int256(digitSpacing * (9 - d8));
        int256 p8BeginPhase = -int256(secondsIntoCycle9 % (BASE * 100000000));
        uint256 p8X = startX + (3 * spacing) - 24;
        uint256 p8Y = startY + ((2 - 2) * 120) - 40;
        
        // Place 9 (billions) - sync to its own cycle
        uint256 cycle10 = BASE * 10000000000;
        uint256 secondsIntoCycle10 = nowTs % cycle10;
        int256 p9BaseOffset = -int256(digitSpacing * (9 - d9));
        int256 p9BeginPhase = -int256(secondsIntoCycle10 % (BASE * 1000000000));
        uint256 p9X = startX + (2 * spacing) - 24;
        uint256 p9Y = startY + ((2 - 2) * 120) - 40;
        
        // Place 10 (ten billions) - sync to its own cycle
        uint256 cycle11 = BASE * 100000000000;
        uint256 secondsIntoCycle11 = nowTs % cycle11;
        int256 p10BaseOffset = -int256(digitSpacing * (9 - d10));
        int256 p10BeginPhase = -int256(secondsIntoCycle11 % (BASE * 10000000000));
        uint256 p10X = startX + (1 * spacing) - 24;
        uint256 p10Y = startY + ((2 - 2) * 120) - 40;
        
        // Place 11 (hundred billions) - sync to its own cycle
        uint256 cycle12 = BASE * 1000000000000;
        uint256 secondsIntoCycle12 = nowTs % cycle12;
        int256 p11BaseOffset = -int256(digitSpacing * (9 - d11));
        int256 p11BeginPhase = -int256(secondsIntoCycle12 % (BASE * 100000000000));
        uint256 p11X = startX + (0 * spacing) - 24;
        uint256 p11Y = startY + ((2 - 2) * 120) - 40;
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<defs>',
            _digitGlyphs(),
            _clipPaths(),
            '<path id="circlePath" d="M 300,20 A 280,280 0 1,1 299.9,20" fill="none"/>',
            '</defs>',
            '<rect width="600" height="600" fill="#000"/>',
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            '<g fill="#fff">',
            _animatedDigitColumn(p11X, p11Y, p11BaseOffset, p11BeginPhase, BASE * 1000000000000, 11),
            _animatedDigitColumn(p10X, p10Y, p10BaseOffset, p10BeginPhase, BASE * 100000000000, 10),
            _animatedDigitColumn(p9X, p9Y, p9BaseOffset, p9BeginPhase, BASE * 10000000000, 9),
            _animatedDigitColumn(p8X, p8Y, p8BaseOffset, p8BeginPhase, BASE * 1000000000, 8),
            _animatedDigitColumn(p7X, p7Y, p7BaseOffset, p7BeginPhase, BASE * 100000000, 7),
            _animatedDigitColumn(p6X, p6Y, p6BaseOffset, p6BeginPhase, BASE * 10000000, 6),
            _animatedDigitColumn(p5X, p5Y, p5BaseOffset, p5BeginPhase, BASE * 1000000, 5),
            _animatedDigitColumn(p4X, p4Y, p4BaseOffset, p4BeginPhase, BASE * 100000, 4),
            _animatedDigitColumn(p3X, p3Y, p3BaseOffset, p3BeginPhase, BASE * 10000, 3),
            _animatedDigitColumn(p2X, p2Y, p2BaseOffset, p2BeginPhase, BASE * 1000, 2),
            _animatedDigitColumn(p1X, p1Y, p1BaseOffset, p1BeginPhase, BASE * 100, 1),
            _animatedDigitColumn(p0X, p0Y, p0BaseOffset, p0BeginPhase, BASE * 10, 0),
            '</g>',
            '<circle r="', _uint2str(ballRadius), '" fill="#fff">',
            '<animateMotion dur="', _uint2str(ballTimeRemaining), 's" rotate="auto" fill="freeze">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '<animateMotion dur="', _uint2str(BASE), 's" begin="', _uint2str(ballTimeRemaining), 's" rotate="auto" repeatCount="indefinite">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '</circle>',
            '</svg>'
        ));
    }
    
    function _clipPaths() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<clipPath id="clip0"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip1"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip2"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip3"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip4"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip5"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip6"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip7"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip8"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip9"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip10"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="clip11"><rect x="0" y="0" width="48" height="80"/></clipPath>'
        ));
    }
    
    function _animatedDigitColumn(
        uint256 x,
        uint256 y,
        int256 baseOffset,
        int256 beginPhase,
        uint256 duration,
        uint256 clipId
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<g clip-path="url(#clip', _uint2str(clipId), ')" transform="translate(', _uint2str(x), ',', _uint2str(y), ')">',
            '<g transform="translate(0,', _int2str(baseOffset), ')">',
            _digitStack(),
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="0,0;0,-80;0,-160;0,-240;0,-320;0,-400;0,-480;0,-560;0,-640;0,-720" ',
            'dur="', _uint2str(duration), 's" ',
            'begin="', _int2str(beginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>'
        ));
    }
    
    function _digitStack() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="80"/>',
            '<use href="#d7" y="160"/>',
            '<use href="#d6" y="240"/>',
            '<use href="#d5" y="320"/>',
            '<use href="#d4" y="400"/>',
            '<use href="#d3" y="480"/>',
            '<use href="#d2" y="560"/>',
            '<use href="#d1" y="640"/>',
            '<use href="#d0" y="720"/>',
            '<use href="#d9" y="800"/>'
        ));
    }
    
    function _digitGlyphs() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<g id="d0" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d1" transform="translate(8,0)"><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d2" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d3" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d4" transform="translate(8,0)"><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d5" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d6" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d7" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d8" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d9" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>'
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
    
    function _int2str(int256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        bool negative = value < 0;
        uint256 abs = uint256(negative ? -value : value);
        string memory num = _uint2str(abs);
        return negative ? string(abi.encodePacked("-", num)) : num;
    }
}
