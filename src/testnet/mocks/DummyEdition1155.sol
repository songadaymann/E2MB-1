// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title DummyEdition1155
/// @notice Minimal ERC-1155 contract for burn-to-points testing (edition style mints)
contract DummyEdition1155 is ERC1155Burnable, Ownable {
    constructor() ERC1155("ipfs://dummy-edition/{id}") Ownable(msg.sender) {}

    /// @notice Mint an edition token to `to`
    /// @param to recipient
    /// @param id token id (manually chosen)
    /// @param amount number of copies to mint
    function mintEdition(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    /// @notice Convenience burn for caller
    function burnSelf(uint256 id, uint256 amount) external {
        _burn(msg.sender, id, amount);
    }
}
