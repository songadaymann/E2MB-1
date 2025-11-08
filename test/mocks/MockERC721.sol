// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Mock", "MOCK") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function refreshMetadata(uint256) external pure {}
}

