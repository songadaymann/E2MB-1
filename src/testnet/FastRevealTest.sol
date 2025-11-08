// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/EveryTwoMillionBlocks.sol";

/// @title FastRevealTest
/// @notice Fast 5-minute reveals for testnet, inheriting from production EveryTwoMillionBlocks
/// @dev Overrides only timing functions - everything else is production code
contract FastRevealTest is EveryTwoMillionBlocks {
    
    uint256 public immutable deployTimestamp;
    uint256 public constant REVEAL_INTERVAL = 5 minutes;
    
    event FastRevealDeployed(uint256 deployTime, uint256 interval);
    
    constructor() {
        deployTimestamp = block.timestamp;
        emit FastRevealDeployed(deployTimestamp, REVEAL_INTERVAL);
    }
    
    /// @notice Override: Use simple tokenID-based ranking (no points for testing)
    /// @dev Token #1 → rank 0, Token #2 → rank 1, etc.
    function getCurrentRank(uint256 tokenId) public view override returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenId - 1;
    }
    
    /// @notice Override: 5-minute intervals instead of yearly Jan 1 UTC timestamps
    /// @dev Converts year to rank and calculates deployment + (rank × 5 minutes)
    function _jan1Timestamp(uint256 year) internal view override returns (uint256) {
        // Convert year to rank: year 2026 → rank 0, year 2027 → rank 1, etc.
        uint256 rank = year >= START_YEAR ? year - START_YEAR : 0;
        return deployTimestamp + (rank * REVEAL_INTERVAL);
    }
    
    /// @notice Batch mint helper for testing
    /// @dev Mints sequential tokens with different seeds
    function batchMint(address to, uint256 count) external onlyOwner {
        require(count > 0 && count <= 100, "Count must be 1-100");
        
        for (uint256 i = 0; i < count; i++) {
            uint32 seed = uint32(block.timestamp + i);
            this.mint(to, seed);  // Call parent's mint function
        }
    }
    
    /// @notice Get reveal time for a token (helper)
    function getRevealTime(uint256 tokenId) external view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        uint256 rank = getCurrentRank(tokenId);
        uint256 year = START_YEAR + rank;
        return _jan1Timestamp(year);
    }
    
    /// @notice Get time remaining until reveal
    function getTimeUntilReveal(uint256 tokenId) external view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        uint256 rank = getCurrentRank(tokenId);
        uint256 year = START_YEAR + rank;
        uint256 revealTime = _jan1Timestamp(year);
        
        return block.timestamp >= revealTime ? 0 : revealTime - block.timestamp;
    }
    
    /// @notice Check if token is revealed (convenience function)
    function isTokenRevealed(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        uint256 rank = getCurrentRank(tokenId);
        uint256 year = START_YEAR + rank;
        uint256 revealTime = _jan1Timestamp(year);
        
        return block.timestamp >= revealTime;
    }
}
