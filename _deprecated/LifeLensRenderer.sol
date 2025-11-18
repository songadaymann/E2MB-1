// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./ILifeLens.sol";
import "./LifeSVG.sol";
import "./LifeScript.sol";

interface IRefreshableERC721 is IERC721 {
    function refreshMetadata(uint256 tokenId) external;
}

contract LifeLensRenderer is Ownable {
    using Strings for uint256;

    IERC721 public immutable tokenContract;

    mapping(uint256 => ILifeLens) public lenses;
    uint256[] public lensIds;

    mapping(uint256 => uint256) private tokenLens;

    event LensRegistered(uint256 indexed lensId, address lens);
    event LensRemoved(uint256 indexed lensId);
    event TokenLensUpdated(uint256 indexed tokenId, uint256 lensId);

    constructor(address _tokenContract, address initialLens) Ownable(msg.sender) {
        require(_tokenContract != address(0), "LifeLensRenderer: token contract required");
        tokenContract = IERC721(_tokenContract);

        if (initialLens != address(0)) {
            lenses[1] = ILifeLens(initialLens);
            lensIds.push(1);
        }
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "LifeLensRenderer: nonexistent token");

        ILifeLens lens = _lensForToken(tokenId);
        ILifeLens.LifeBoard memory board = lens.board(tokenId);
        bytes[2] memory palette = lens.colors();

        string memory svg = LifeSVG.generateSVG(board, palette);
        string memory script = LifeScript.generateScript(board, lens.name());
        string memory html = Base64.encode(
            abi.encodePacked(
                "<!DOCTYPE html><html><head><meta charset='utf-8'/>",
                "<style>body{background:",
                palette[0],
                ";display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;font-family:monospace;color:",
                palette[1],
                ";}#life-container{display:flex;flex-direction:column;align-items:center;justify-content:center;width:100%;gap:18px;text-align:center;}#life-title{letter-spacing:1px;font-size:12px;text-transform:uppercase;opacity:0.8;}</style></head><body><div id='life-container'>",
                svg,
                "<div id='life-title'></div></div><script>",
                script,
                "</script></body></html>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"Life Lens ',
                        lens.name(),
                        '","description":"Game of Life pre-reveal lens.",',
                        '"image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '","animation_url":"data:text/html;base64,',
                        html,
                        '","attributes":[{"trait_type":"Lens","value":"',
                        lens.name(),
                        '"},{"trait_type":"Lens Text","value":"',
                        lens.text(),
                        '"}]}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function registerLens(uint256 lensId, address lens) external onlyOwner {
        require(lensId != 0, "LifeLensRenderer: invalid id");
        require(lens != address(0), "LifeLensRenderer: invalid lens");
        lenses[lensId] = ILifeLens(lens);
        if (!_lensExists(lensId)) {
            lensIds.push(lensId);
        }
        emit LensRegistered(lensId, lens);
    }

    function removeLens(uint256 lensId) external onlyOwner {
        require(address(lenses[lensId]) != address(0), "LifeLensRenderer: unknown lens");
        delete lenses[lensId];
        _removeLensId(lensId);
        emit LensRemoved(lensId);
    }

    function setTokenLens(uint256 tokenId, uint256 lensId) external {
        require(_isApprovedOrOwner(tokenId), "LifeLensRenderer: not authorized");
        require(address(lenses[lensId]) != address(0), "LifeLensRenderer: lens missing");
        tokenLens[tokenId] = lensId;
        emit TokenLensUpdated(tokenId, lensId);
        _tryRefresh(tokenId);
    }

    function getTokenLens(uint256 tokenId) external view returns (uint256) {
        return tokenLens[tokenId];
    }

    function _lensForToken(uint256 tokenId) internal view returns (ILifeLens) {
        uint256 lensId = tokenLens[tokenId];
        if (lensId == 0) {
            lensId = lensIds.length > 0 ? lensIds[0] : 0;
        }
        require(lensId != 0 && address(lenses[lensId]) != address(0), "LifeLensRenderer: no lens configured");
        return lenses[lensId];
    }

    function _lensExists(uint256 lensId) private view returns (bool) {
        for (uint256 i = 0; i < lensIds.length; i++) {
            if (lensIds[i] == lensId) {
                return true;
            }
        }
        return false;
    }

    function _removeLensId(uint256 lensId) private {
        for (uint256 i = 0; i < lensIds.length; i++) {
            if (lensIds[i] == lensId) {
                lensIds[i] = lensIds[lensIds.length - 1];
                lensIds.pop();
                return;
            }
        }
    }

    function _exists(uint256 tokenId) private view returns (bool) {
        try tokenContract.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    function _isApprovedOrOwner(uint256 tokenId) private view returns (bool) {
        address owner = tokenContract.ownerOf(tokenId);
        if (msg.sender == owner || tokenContract.getApproved(tokenId) == msg.sender || tokenContract.isApprovedForAll(owner, msg.sender)) {
            return true;
        }
        return false;
    }

    function _tryRefresh(uint256 tokenId) private {
        if (address(tokenContract).code.length == 0) return;
        (bool success, ) = address(tokenContract).call(
            abi.encodeWithSelector(IRefreshableERC721.refreshMetadata.selector, tokenId)
        );
        success;
    }
}
