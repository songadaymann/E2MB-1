// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILifeLens {
    struct LifeBoard {
        uint8 width;
        uint8 height;
        bytes initialCells; // width * height bytes, each cell 0 or 1
        uint32 baseSeed;
        uint16 markovSteps;
        int16[] leadPitches;
        uint16[] leadDurations;
        int16[] bassPitches;
        uint16[] bassDurations;
        uint32[] wordSeeds;
        uint256 currentRank;
        uint256 totalTokens;
        uint256 revealTimestamp;
        bool isRevealed;
        string wordsText;
        uint256 revealYear;
    }

    function name() external view returns (string memory);

    function colors() external view returns (bytes[2] memory);

    function text() external view returns (string memory);

    function board(uint256 tokenId) external view returns (LifeBoard memory);
}
