// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPointsManager
 * @notice Interface for PointsManager contract
 * @dev Used by EveryTwoMillionBlocks NFT to query points and rankings
 */
interface IPointsManager {
    /// @notice Get points for a token
    function pointsOf(uint256 tokenId) external view returns (uint256);
    
    /// @notice Get current rank for a token (0-indexed)
    function currentRankOf(uint256 tokenId) external view returns (uint256);
    
    /// @notice Add points to a token (admin only)
    function addPoints(uint256 tokenId, uint256 amount, string calldata source) external;

    /// @notice Configure eligible L1 asset and base value (owner only)
    function addEligibleL1Asset(address nft, uint256 baseValue) external;

    /// @notice Update month weights (owner only)
    function setMonthWeights(uint256[12] calldata weights) external;

    /// @notice Update messenger addresses (owner only)
    function setMessengers(
        address base,
        address optimism,
        address arbitrum,
        address zora
    ) external;
}
