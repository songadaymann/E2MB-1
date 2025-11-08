// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRevealQueue {
    function basePermutation(uint256 tokenId) external view returns (uint256);
    function totalMinted() external view returns (uint256);
    function hasSevenWords(uint256 tokenId) external view returns (bool);
}
