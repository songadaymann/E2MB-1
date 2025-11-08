// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRevealQueue.sol";

contract PointsManager is Ownable {
    mapping(uint256 => uint256) public points;

    address public aggregator; // PointsAggregator
    IRevealQueue public revealQueue; // EveryTwoMillionBlocks
    bool public permutationZeroIndexed;

    uint256[] private activeTokens;
    mapping(uint256 => uint256) private activeIndex; // tokenId => index+1
    mapping(uint256 => bool) public revealed;
    uint256[] private revealedTokens;

    event PointsApplied(uint256 indexed tokenId, uint256 delta, uint256 newTotal, string source);
    event AggregatorUpdated(address indexed aggregator);
    event RevealQueueUpdated(address indexed revealQueue);
    event PermutationIndexingUpdated(bool zeroIndexed);
    event TokenActivated(uint256 indexed tokenId);
    event TokenDeactivated(uint256 indexed tokenId);
    event TokenRevealed(uint256 indexed tokenId);

    constructor() Ownable(msg.sender) {}

    function setAggregator(address _aggregator) external onlyOwner {
        aggregator = _aggregator;
        emit AggregatorUpdated(_aggregator);
    }

    function setRevealQueue(address _revealQueue) external onlyOwner {
        revealQueue = IRevealQueue(_revealQueue);
        emit RevealQueueUpdated(_revealQueue);
    }

    function setPermutationZeroIndexed(bool value) external onlyOwner {
        permutationZeroIndexed = value;
        emit PermutationIndexingUpdated(value);
    }

    function addPoints(uint256 tokenId, uint256 amount, string calldata source) external {
        require(msg.sender == aggregator, "Only aggregator");
        _enforceSevenWords(tokenId);
        require(!revealed[tokenId], "Token revealed");
        if (amount == 0) {
            emit PointsApplied(tokenId, 0, points[tokenId], source);
            return;
        }

        uint256 previous = points[tokenId];
        uint256 updated = previous + amount;
        points[tokenId] = updated;

        if (previous == 0) {
            _activate(tokenId);
        }

        emit PointsApplied(tokenId, amount, updated, source);
    }

    function handleReveal(uint256 tokenId) external {
        require(msg.sender == aggregator, "Only aggregator");
        if (revealed[tokenId]) {
            return;
        }

        revealed[tokenId] = true;
        _deactivate(tokenId);
        revealedTokens.push(tokenId);
        emit TokenRevealed(tokenId);
    }

    function getPoints(uint256 tokenId) external view returns (uint256) {
        return points[tokenId];
    }

    function pointsOf(uint256 tokenId) external view returns (uint256) {
        return points[tokenId];
    }

    function activeTokenCount() external view returns (uint256) {
        return activeTokens.length;
    }

    function activeTokenAt(uint256 index) external view returns (uint256) {
        require(index < activeTokens.length, "Index out of bounds");
        return activeTokens[index];
    }

    function isActive(uint256 tokenId) external view returns (bool) {
        return activeIndex[tokenId] != 0;
    }

    function revealedCount() external view returns (uint256) {
        return revealedTokens.length;
    }

    function revealedTokenAt(uint256 index) external view returns (uint256) {
        require(index < revealedTokens.length, "Index out of bounds");
        return revealedTokens[index];
    }

    function currentRankOf(uint256 tokenId) external view returns (uint256) {
        require(!revealed[tokenId], "Token revealed");

        uint256 myPoints = points[tokenId];
        uint256 myBaseIndex = _baseIndex(tokenId);
        uint256 rank = 0;

        uint256 len = activeTokens.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 otherId = activeTokens[i];
            if (otherId == tokenId) continue;

            uint256 otherPoints = points[otherId];
            if (otherPoints > myPoints) {
                rank++;
                continue;
            }

            if (otherPoints == myPoints) {
                uint256 otherBaseIndex = _baseIndex(otherId);
                if (otherBaseIndex < myBaseIndex) {
                    rank++;
                    continue;
                }
                if (otherBaseIndex == myBaseIndex && otherId < tokenId) {
                    rank++;
                }
            }
        }

        if (myPoints > 0) {
            return rank;
        }

        rank += len;
        uint256 revealedBefore = _revealedBefore(myBaseIndex);
        return rank + myBaseIndex - revealedBefore;
    }

    function _activate(uint256 tokenId) private {
        if (activeIndex[tokenId] != 0) {
            return;
        }
        activeTokens.push(tokenId);
        activeIndex[tokenId] = activeTokens.length;
        emit TokenActivated(tokenId);
    }

    function _deactivate(uint256 tokenId) private {
        uint256 indexPlus = activeIndex[tokenId];
        if (indexPlus == 0) {
            return;
        }

        uint256 index = indexPlus - 1;
        uint256 lastIndex = activeTokens.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = activeTokens[lastIndex];
            activeTokens[index] = lastTokenId;
            activeIndex[lastTokenId] = indexPlus;
        }

        activeTokens.pop();
        activeIndex[tokenId] = 0;
        emit TokenDeactivated(tokenId);
    }

    function _revealedBefore(uint256 baseIndex) private view returns (uint256 count) {
        uint256 len = revealedTokens.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 otherId = revealedTokens[i];
            uint256 otherIndex = _baseIndex(otherId);
            if (otherIndex < baseIndex) {
                unchecked {
                    count++;
                }
            }
        }
    }

    function _baseIndex(uint256 tokenId) private view returns (uint256) {
        if (address(revealQueue) != address(0)) {
            try revealQueue.basePermutation(tokenId) returns (uint256 idx) {
                if (permutationZeroIndexed || idx == 0) {
                    return idx;
                }
                return idx - 1;
            } catch {
                // fallthrough to default
            }
        }
        require(tokenId > 0, "Invalid token");
        return tokenId - 1;
    }

    function _enforceSevenWords(uint256 tokenId) private view {
        if (address(revealQueue) == address(0)) {
            return;
        }
        try revealQueue.hasSevenWords(tokenId) returns (bool ok) {
            require(ok, "Seven words not set");
        } catch {
            revert("Seven words check failed");
        }
    }
}
