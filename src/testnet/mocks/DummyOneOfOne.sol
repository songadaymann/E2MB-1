// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title DummyOneOfOne
/// @notice Minimal ERC-721 contract for burn-to-points testing (1/1 style mints)
contract DummyOneOfOne is ERC721Burnable, Ownable {
    uint256 private _nextId = 1;

    constructor() ERC721("Dummy One Of One", "DUMMY-1OF1") Ownable(msg.sender) {}

    /// @notice Mint a single token to `to`
    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
    }
}
