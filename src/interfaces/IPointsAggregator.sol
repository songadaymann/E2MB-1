// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPointsAggregator {
    function onTokenRevealed(uint256 tokenId) external;
}
