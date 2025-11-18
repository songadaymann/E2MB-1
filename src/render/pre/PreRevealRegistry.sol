// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPreRevealRegistry.sol";

contract PreRevealRegistry is Ownable, IPreRevealRegistry {
    struct RendererSlot {
        address svgRenderer;
        address htmlRenderer;
        bool active;
        bool requiresSevenWords;
    }

    uint256 private _rendererCount;
    uint256 private _defaultRendererId;
    bool private _registryFrozen;

    mapping(uint256 => RendererSlot) private _renderers;
    mapping(uint256 => uint256) private _tokenChoice;
    mapping(uint256 => bool) private _tokenChoiceSet;

    address private _controller;
    bool private _controllerLocked;
    mapping(address => bool) private _curators;

    event ControllerUpdated(address indexed controller);
    event CuratorUpdated(address indexed curator, bool allowed);

    modifier notFrozen() {
        require(!_registryFrozen, "Registry frozen");
        _;
    }

    modifier onlyController() {
        require(msg.sender == _controller, "Not controller");
        _;
    }

    modifier onlyCurator() {
        require(_curators[msg.sender], "Not curator");
        _;
    }

    constructor(address owner_) Ownable(owner_) {
        _curators[owner_] = true;
        emit CuratorUpdated(owner_, true);
    }

    function setController(address controller_) external onlyOwner {
        require(controller_ != address(0), "Controller required");
        require(!_controllerLocked, "Controller locked");
        _controller = controller_;
        _controllerLocked = true;
        emit ControllerUpdated(controller_);
    }

    function addRenderer(address svgRenderer, address htmlRenderer, bool active)
        external
        onlyCurator
        notFrozen
        returns (uint256 rendererId)
    {
        require(svgRenderer != address(0), "SVG renderer required");

        rendererId = _rendererCount;
        _rendererCount += 1;

        _renderers[rendererId] = RendererSlot({
            svgRenderer: svgRenderer,
            htmlRenderer: htmlRenderer,
            active: active,
            requiresSevenWords: false
        });

        if (_rendererCount == 1) {
            _defaultRendererId = 0;
        }
    }

    function updateRenderer(uint256 rendererId, address svgRenderer, address htmlRenderer, bool active)
        external
        onlyOwner
        notFrozen
    {
        require(rendererId < _rendererCount, "Renderer does not exist");
        require(svgRenderer != address(0), "SVG renderer required");

        RendererSlot storage slot = _renderers[rendererId];
        slot.svgRenderer = svgRenderer;
        slot.htmlRenderer = htmlRenderer;
        slot.active = active;
    }

    function setRendererRequiresSevenWords(uint256 rendererId, bool required) external onlyOwner notFrozen {
        require(rendererId < _rendererCount, "Renderer does not exist");
        _renderers[rendererId].requiresSevenWords = required;
    }

    function setDefaultRenderer(uint256 rendererId) external onlyOwner notFrozen {
        require(rendererId < _rendererCount, "Renderer does not exist");
        RendererSlot storage slot = _renderers[rendererId];
        require(slot.active && slot.svgRenderer != address(0), "Renderer inactive");
        _defaultRendererId = rendererId;
    }

    function freeze() external onlyOwner notFrozen {
        _registryFrozen = true;
    }

    function rendererCount() external view returns (uint256) {
        return _rendererCount;
    }

    function defaultRendererId() external view returns (uint256) {
        return _defaultRendererId;
    }

    function registryFrozen() external view returns (bool) {
        return _registryFrozen;
    }

    function getRenderer(uint256 rendererId) external view returns (Renderer memory) {
        require(rendererId < _rendererCount, "Renderer does not exist");
        RendererSlot storage slot = _renderers[rendererId];
        return Renderer(slot.svgRenderer, slot.htmlRenderer, slot.active, slot.requiresSevenWords);
    }

    function getTokenRenderer(uint256 tokenId) external view returns (uint256 rendererId, bool isCustom) {
        if (_tokenChoiceSet[tokenId]) {
            return (_tokenChoice[tokenId], true);
        }
        return (_defaultRendererId, false);
    }

    function setTokenRenderer(uint256 tokenId, uint256 rendererId, bool hasSevenWords) external onlyController {
        _enforceRendererSelection(rendererId, hasSevenWords);
        _tokenChoice[tokenId] = rendererId;
        _tokenChoiceSet[tokenId] = true;
    }

    function clearTokenRenderer(uint256 tokenId) external onlyController {
        if (_tokenChoiceSet[tokenId]) {
            delete _tokenChoice[tokenId];
            _tokenChoiceSet[tokenId] = false;
        }
    }

    function resolveRenderer(uint256 tokenId, bool hasSevenWords)
        external
        view
        returns (uint256 rendererId, address svgRenderer, address htmlRenderer, bool isCustom)
    {
        if (_tokenChoiceSet[tokenId]) {
            uint256 customId = _tokenChoice[tokenId];
            if (_rendererRenderable(customId, hasSevenWords)) {
                RendererSlot storage customSlot = _renderers[customId];
                return (customId, customSlot.svgRenderer, customSlot.htmlRenderer, true);
            }
        }

        require(_rendererRenderable(_defaultRendererId, hasSevenWords), "Default renderer unavailable");
        RendererSlot storage slot = _renderers[_defaultRendererId];
        return (_defaultRendererId, slot.svgRenderer, slot.htmlRenderer, false);
    }

    function controller() external view override returns (address) {
        return _controller;
    }

    function controllerLocked() external view override returns (bool) {
        return _controllerLocked;
    }

    function setCurator(address curator, bool allowed) external onlyOwner {
        require(curator != address(0), "Invalid curator");
        _curators[curator] = allowed;
        emit CuratorUpdated(curator, allowed);
    }

    function isCurator(address account) external view returns (bool) {
        return _curators[account];
    }

    function _enforceRendererSelection(uint256 rendererId, bool hasSevenWords) private view {
        require(rendererId < _rendererCount, "Renderer does not exist");
        require(_rendererRenderable(rendererId, hasSevenWords), "Renderer unavailable");
    }

    function _rendererRenderable(uint256 rendererId, bool hasSevenWords) private view returns (bool) {
        if (rendererId >= _rendererCount) {
            return false;
        }
        RendererSlot storage slot = _renderers[rendererId];
        if (!slot.active || slot.svgRenderer == address(0)) {
            return false;
        }
        if (slot.requiresSevenWords && !hasSevenWords) {
            return false;
        }
        return true;
    }
}
