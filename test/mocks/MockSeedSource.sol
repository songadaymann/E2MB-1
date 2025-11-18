// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/render/pre/life/LifeLensInit.sol";

contract MockSeedSource is ILifeSeedSource {
    mapping(uint256 => uint32) public tokenSeed;
    mapping(uint256 => bytes32) public sevenWords;
    mapping(uint256 => string) private _sevenWordsText;
    bytes32 public previousNotesHash;
    bytes32 public globalState;
    mapping(uint256 => uint256) private _currentRank;
    uint256 public totalMinted;
    mapping(uint256 => bool) public revealed;
    mapping(uint256 => uint256) public revealBlockTimestamp;
    uint256 public startYear = 2026;

    function setTokenSeed(uint256 tokenId, uint32 seed) external {
        tokenSeed[tokenId] = seed;
    }

    function setSevenWords(uint256 tokenId, bytes32 value) external {
        sevenWords[tokenId] = value;
    }

    function setSevenWordsText(uint256 tokenId, string calldata words) external {
        _sevenWordsText[tokenId] = words;
    }

    function setPreviousNotesHash(bytes32 value) external {
        previousNotesHash = value;
    }

    function setGlobalState(bytes32 value) external {
        globalState = value;
    }

    function setCurrentRank(uint256 tokenId, uint256 rank) external {
        _currentRank[tokenId] = rank;
    }

    function setTotalMinted(uint256 total) external {
        totalMinted = total;
    }

    function setRevealed(uint256 tokenId, bool value) external {
        revealed[tokenId] = value;
    }

    function setRevealTimestamp(uint256 tokenId, uint256 timestamp) external {
        revealBlockTimestamp[tokenId] = timestamp;
    }

    function setStartYear(uint256 year) external {
        startYear = year;
    }

    function getCurrentRank(uint256 tokenId) external view returns (uint256) {
        return _currentRank[tokenId];
    }

    function START_YEAR() external view returns (uint256) {
        return startYear;
    }

    function sevenWordsText(uint256 tokenId) external view returns (string memory) {
        return _sevenWordsText[tokenId];
    }
}
