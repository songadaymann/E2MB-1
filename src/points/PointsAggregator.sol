// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PointsManager.sol";

contract PointsAggregator is Ownable {
    PointsManager public pointsManager;
    address public l1BurnCollector;
    address public nftContract;
    mapping(address => bool) public authorizedCollectors;

    event CheckpointApplied(string chain, uint256 entryCount, uint256 totalPoints);
    event DirectPointsAwarded(uint256 indexed tokenId, uint256 amount, string source);
    event L1BurnCollectorUpdated(address indexed collector);
    event NftContractUpdated(address indexed nftContract);
    event TokenRevealForwarded(uint256 indexed tokenId);
    event CollectorAuthorizationUpdated(address indexed collector, bool allowed);

    constructor(address _pointsManager) Ownable(msg.sender) {
        pointsManager = PointsManager(_pointsManager);
        // setAggregator will be called after deployment
    }

    function setL1BurnCollector(address _collector) external onlyOwner {
        if (l1BurnCollector != address(0) && l1BurnCollector != _collector) {
            authorizedCollectors[l1BurnCollector] = false;
            emit CollectorAuthorizationUpdated(l1BurnCollector, false);
        }

        l1BurnCollector = _collector;
        if (_collector != address(0)) {
            authorizedCollectors[_collector] = true;
            emit CollectorAuthorizationUpdated(_collector, true);
        }
        emit L1BurnCollectorUpdated(_collector);
    }

    function setAuthorizedCollector(address collector, bool allowed) external onlyOwner {
        require(collector != address(0), "Invalid collector");
        authorizedCollectors[collector] = allowed;
        if (collector == l1BurnCollector && !allowed) {
            l1BurnCollector = address(0);
            emit L1BurnCollectorUpdated(address(0));
        }
        emit CollectorAuthorizationUpdated(collector, allowed);
    }

    function initializePointsManager() external onlyOwner {
        pointsManager.setAggregator(address(this));
    }

    function transferPointsManagerOwnership(address newOwner) external onlyOwner {
        pointsManager.transferOwnership(newOwner);
    }

    function setNftContract(address _nftContract) external onlyOwner {
        nftContract = _nftContract;
        emit NftContractUpdated(_nftContract);
    }

    // For L1 burns
    function applyCheckpointFromBase(bytes calldata payload) external {
        require(authorizedCollectors[msg.sender], "Unauthorized collector");
        (uint256[] memory tokenIds, uint256[] memory deltas, string[] memory sources) = abi.decode(payload, (uint256[], uint256[], string[]));
        require(tokenIds.length == deltas.length && deltas.length == sources.length, "Mismatched arrays");
        uint256 totalPoints = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            pointsManager.addPoints(tokenIds[i], deltas[i], sources[i]);
            totalPoints += deltas[i];
        }
        emit CheckpointApplied("base", tokenIds.length, totalPoints);
    }

    // Placeholder for L2
    function applyCheckpointFromOptimism(bytes calldata payload) external {
        // Validate messenger (placeholder)
        // Apply similar to above
    }

    function directAward(uint256 tokenId, uint256 amount, string calldata source) external onlyOwner {
        pointsManager.addPoints(tokenId, amount, source);
        emit DirectPointsAwarded(tokenId, amount, source);
    }

    function onTokenRevealed(uint256 tokenId) external {
        require(msg.sender == nftContract, "Unauthorized reveal");
        pointsManager.handleReveal(tokenId);
        emit TokenRevealForwarded(tokenId);
    }
}
