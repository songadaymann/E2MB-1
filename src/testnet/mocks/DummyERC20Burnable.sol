// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title DummyERC20Burnable
/// @notice Simple ERC-20 with owner-controlled minting and open burn for testing
contract DummyERC20Burnable is ERC20Burnable, Ownable {
    constructor() ERC20("Dummy Burnable Token", "DUM20") Ownable(msg.sender) {}

    /// @notice Mint tokens to recipient (owner only)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
