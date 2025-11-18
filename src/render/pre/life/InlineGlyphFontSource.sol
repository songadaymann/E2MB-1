// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../utils/SSTORE2.sol";

/// @notice Stores the LifeGlyphs font as a base64-encoded data URI chunk via SSTORE2.
contract InlineGlyphFontSource {
    address public immutable owner;
    address public fontPointer;
    bool public fontLocked;

    error NotOwner();
    error FontLocked();
    error FontNotSet();
    error FontDataEmpty();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Uploads the base64-encoded font data.
    function uploadFont(bytes calldata base64Data) external onlyOwner {
        if (fontLocked) revert FontLocked();
        if (base64Data.length == 0) revert FontDataEmpty();
        fontPointer = SSTORE2.write(base64Data);
    }

    /// @notice Locks the font pointer, preventing future uploads.
    function lockFont() external onlyOwner {
        if (fontPointer == address(0)) revert FontNotSet();
        fontLocked = true;
    }

    /// @notice Returns the `@font-face` CSS snippet for the stored font.
    function fontFaceCSS() external view returns (string memory) {
        return string(
            abi.encodePacked(
                "@font-face{font-family:'LifeGlyphs';font-style:normal;font-weight:400;font-display:swap;src:url(data:font/woff2;base64,",
                _fontBase64(),
                ") format('woff2');}"
            )
        );
    }

    function _fontBase64() internal view returns (string memory) {
        address pointer = fontPointer;
        if (pointer == address(0)) revert FontNotSet();
        return string(SSTORE2.read(pointer));
    }
}
