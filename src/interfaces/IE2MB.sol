// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IE2MB
 * @notice Interface for EveryTwoMillionBlocks NFT contract
 * @dev Used by PointsManager to read NFT state for ranking
 */
interface IE2MB {
    /// @notice Get the base permutation index for a token (from VRF)
    function basePermutation(uint256 tokenId) external view returns (uint256);
    
    /// @notice Get total number of minted tokens
    function totalMinted() external view returns (uint256);
}
