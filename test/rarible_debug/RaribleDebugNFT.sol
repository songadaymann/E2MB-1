// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RaribleDebugNFT is ERC721, Ownable {
    uint256 public nextTokenId = 1;
    string public constant DEFAULT_TOKEN_URI = "ipfs://bafkreicxwkiplxmteqvlm35m4o66is2dxnatm72a4g53wlpatlwz5oueha";
    mapping(uint256 => string) private tokenUris;

    constructor() ERC721("Rarible Debug Token", "RDT") Ownable(msg.sender) {}

    function mint(address to, string calldata customUri) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        if (bytes(customUri).length > 0) {
            tokenUris[tokenId] = customUri;
        }
    }

    function updateTokenURI(uint256 tokenId, string calldata newUri) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");
        tokenUris[tokenId] = newUri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");
        string memory stored = tokenUris[tokenId];
        if (bytes(stored).length > 0) {
            return stored;
        }
        return DEFAULT_TOKEN_URI;
    }
}
