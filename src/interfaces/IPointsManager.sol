// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPointsManager
 * @notice Interface for PointsManager contract
 */
interface IPointsManager {
    function pointsOf(uint256 tokenId) external view returns (uint256);
    function currentRankOf(uint256 tokenId) external view returns (uint256);
    function addPoints(uint256 tokenId, uint256 amount, string calldata source) external;
    function handleReveal(uint256 tokenId) external;
}
