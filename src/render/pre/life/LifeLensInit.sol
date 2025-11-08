// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ILifeLens.sol";
import "../../../interfaces/ISongAlgorithm.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface ILifeSeedSource {
    function tokenSeed(uint256 tokenId) external view returns (uint32);
    function sevenWords(uint256 tokenId) external view returns (bytes32);
    function previousNotesHash() external view returns (bytes32);
    function globalState() external view returns (bytes32);
    function getCurrentRank(uint256 tokenId) external view returns (uint256);
    function totalMinted() external view returns (uint256);
    function revealed(uint256 tokenId) external view returns (bool);
    function revealBlockTimestamp(uint256 tokenId) external view returns (uint256);
    function START_YEAR() external view returns (uint256);
}

contract LifeLensInit is ILifeLens {
    using Strings for uint256;

    IERC721 public immutable tokenContract;
    ILifeSeedSource public immutable seedSource;
    ISongAlgorithm public immutable songAlgorithm;

    uint16 private constant MARKOV_STEPS = 32;
    uint8 private constant BOARD_SIZE = 8;
    uint8 private constant MIN_ALIVE = 6;

    constructor(address _tokenContract, ILifeSeedSource _seedSource, ISongAlgorithm _songAlgorithm) {
        require(_tokenContract != address(0), "LifeLensInit: token required");
        require(address(_seedSource) != address(0), "LifeLensInit: seed source required");
        require(address(_songAlgorithm) != address(0), "LifeLensInit: algorithm required");
        tokenContract = IERC721(_tokenContract);
        seedSource = _seedSource;
        songAlgorithm = _songAlgorithm;
    }

    function name() external pure override returns (string memory) {
        return "Life: Init Seed";
    }

    function colors() external pure override returns (bytes[2] memory) {
        return [bytes("#000000"), bytes("#ffffff")];
    }

    function text() external view override returns (string memory) {
        try tokenContract.ownerOf(1) returns (address owner) {
            return string(abi.encodePacked("Owner ", _toHex(owner)));
        } catch {
            return "Owner Unknown";
        }
    }

    function board(uint256 tokenId) external view override returns (LifeBoard memory) {
        bytes memory initialCells = new bytes(BOARD_SIZE * BOARD_SIZE);
        uint32 seed = _computeSeed(tokenId);
        uint32 rng = seed == 0 ? 1 : seed;
        uint256 aliveCount;

        for (uint256 i = 0; i < initialCells.length; i++) {
            rng = _lcg(rng);
            bool alive = (rng & 0xFFFF) % 5 < 2; // ~40% chance alive
            if (alive) {
                initialCells[i] = bytes1(uint8(1));
                aliveCount++;
            }
        }

        if (aliveCount < MIN_ALIVE) {
            for (uint256 i = 0; i < initialCells.length && aliveCount < MIN_ALIVE; i++) {
                if (initialCells[i] == bytes1(uint8(0))) {
                    initialCells[i] = bytes1(uint8(1));
                    aliveCount++;
                }
            }
        }

        int16[] memory leadPitches = new int16[](MARKOV_STEPS);
        uint16[] memory leadDurations = new uint16[](MARKOV_STEPS);
        int16[] memory bassPitches = new int16[](MARKOV_STEPS);
        uint16[] memory bassDurations = new uint16[](MARKOV_STEPS);

        for (uint16 i = 0; i < MARKOV_STEPS; i++) {
            (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = songAlgorithm.generateBeat(i, seed);
            leadPitches[i] = lead.pitch;
            leadDurations[i] = lead.duration;
            bassPitches[i] = bass.pitch;
            bassDurations[i] = bass.duration;
        }

        uint256 currentRank = seedSource.getCurrentRank(tokenId);
        uint256 totalTokens = seedSource.totalMinted();
        bool revealedState = seedSource.revealed(tokenId);
        uint256 revealTs = 0;
        if (revealedState) {
            revealTs = seedSource.revealBlockTimestamp(tokenId);
        } else {
            uint256 startYear = seedSource.START_YEAR();
            uint256 revealYear = startYear + currentRank;
            revealTs = _jan1Timestamp(revealYear);
        }

        return LifeBoard({
            width: BOARD_SIZE,
            height: BOARD_SIZE,
            initialCells: initialCells,
            baseSeed: seed,
            markovSteps: MARKOV_STEPS,
            leadPitches: leadPitches,
            leadDurations: leadDurations,
            bassPitches: bassPitches,
            bassDurations: bassDurations,
            currentRank: currentRank,
            totalTokens: totalTokens,
            revealTimestamp: revealTs,
            isRevealed: revealedState
        });
    }

    function _toHex(address account) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(account)), 20);
    }

    function _computeSeed(uint256 tokenId) private view returns (uint32) {
        uint32 baseSeed = seedSource.tokenSeed(tokenId);
        bytes32 words = seedSource.sevenWords(tokenId);
        bytes32 previous = seedSource.previousNotesHash();
        bytes32 global = seedSource.globalState();
        if (baseSeed == 0 && words == bytes32(0) && previous == bytes32(0) && global == bytes32(0)) {
            // Fallback for tokens not yet fully configured
            return uint32(uint256(keccak256(abi.encodePacked(tokenId, address(tokenContract)))));
        }
        return uint32(uint256(keccak256(abi.encodePacked(baseSeed, words, previous, global, tokenId))));
    }

    function _lcg(uint32 state) private pure returns (uint32) {
        unchecked {
            return state * 1664525 + 1013904223;
        }
    }

    function _jan1Timestamp(uint256 year) internal pure returns (uint256) {
        require(year >= 1970, "LifeLensInit: year too small");
        uint256 dayCount;
        for (uint256 y = 1970; y < year; y++) {
            dayCount += _isLeapYear(y) ? 366 : 365;
        }
        return dayCount * 1 days;
    }

    function _isLeapYear(uint256 year) private pure returns (bool) {
        if (year % 400 == 0) return true;
        if (year % 100 == 0) return false;
        if (year % 4 == 0) return true;
        return false;
    }
}
