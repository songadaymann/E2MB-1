// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPreRevealRegistry {
    struct Renderer {
        address svgRenderer;
        address htmlRenderer;
        bool active;
        bool requiresSevenWords;
    }

    function addRenderer(address svgRenderer, address htmlRenderer, bool active) external returns (uint256);

    function updateRenderer(uint256 rendererId, address svgRenderer, address htmlRenderer, bool active) external;

    function setRendererRequiresSevenWords(uint256 rendererId, bool required) external;

    function setDefaultRenderer(uint256 rendererId) external;

    function freeze() external;

    function rendererCount() external view returns (uint256);

    function defaultRendererId() external view returns (uint256);

    function registryFrozen() external view returns (bool);

    function getRenderer(uint256 rendererId) external view returns (Renderer memory);

    function getTokenRenderer(uint256 tokenId) external view returns (uint256 rendererId, bool isCustom);

    function setTokenRenderer(uint256 tokenId, uint256 rendererId, bool hasSevenWords) external;

    function clearTokenRenderer(uint256 tokenId) external;

    function resolveRenderer(uint256 tokenId, bool hasSevenWords)
        external
        view
        returns (uint256 rendererId, address svgRenderer, address htmlRenderer, bool isCustom);

    function setController(address controller) external;

    function controller() external view returns (address);

    function controllerLocked() external view returns (bool);
}
