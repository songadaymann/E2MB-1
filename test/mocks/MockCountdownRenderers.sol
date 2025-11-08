// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/render/IRenderTypes.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockCountdownRenderer {
    using Strings for uint256;

    string public prefix;
    bool public shouldRevert;

    constructor(string memory _prefix) {
        prefix = _prefix;
    }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        if (shouldRevert) {
            revert("MockCountdownRenderer: revert requested");
        }
        return string(abi.encodePacked("<svg>", prefix, ctx.tokenId.toString(), "</svg>"));
    }
}

contract MockCountdownHtmlRenderer {
    using Strings for uint256;

    string public prefix;
    bool public shouldRevert;

    constructor(string memory _prefix) {
        prefix = _prefix;
    }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory) {
        if (shouldRevert) {
            revert("MockCountdownHtmlRenderer: revert requested");
        }
        return string(abi.encodePacked("data:text/html;base64,", prefix, ctx.tokenId.toString()));
    }
}
