// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPointsManager.sol";

/// @title PointsAggregator
/// @notice Receives cross-chain checkpoints and applies points to PointsManager
/// @dev For Sepolia testing we can set messenger addresses to EOAs; on mainnet use canonical messenger contracts
contract PointsAggregator is Ownable {
    IPointsManager public immutable pointsManager;

    address public baseMessenger;
    address public optimismMessenger;
    address public arbitrumInbox;
    address public zoraMessenger;
    address public l1BurnCollector; // For L1 checkpoints

    event MessengersConfigured(
        address indexed base,
        address indexed optimism,
        address indexed arbitrum,
        address zora
    );

    event CheckpointApplied(string chain, uint256 entryCount, uint256 totalPoints);
    event DirectPointsAwarded(uint256 indexed tokenId, uint256 amount, string source);

    constructor(address pointsManagerAddress) Ownable(msg.sender) {
        require(pointsManagerAddress != address(0), "PointsManager required");
        pointsManager = IPointsManager(pointsManagerAddress);
    }

    /// @notice Configure messenger addresses (must match canonical messenger contracts in production)
    function setMessengers(
        address base,
        address optimism,
        address arbitrum,
        address zora
    ) external onlyOwner {
        baseMessenger = base;
        optimismMessenger = optimism;
        arbitrumInbox = arbitrum;
        zoraMessenger = zora;

        emit MessengersConfigured(base, optimism, arbitrum, zora);
    }

    /// @notice Apply a checkpoint arriving from Base
    function applyCheckpointFromBase(bytes calldata payload) external {
        require(msg.sender == baseMessenger, "Invalid Base messenger");
        _applyCheckpoint("Base", payload);
    }

    /// @notice Apply a checkpoint arriving from Optimism
    function applyCheckpointFromOptimism(bytes calldata payload) external {
        require(msg.sender == optimismMessenger, "Invalid Optimism messenger");
        _applyCheckpoint("Optimism", payload);
    }

    /// @notice Apply a checkpoint arriving from Arbitrum
    function applyCheckpointFromArbitrum(bytes calldata payload) external {
        require(msg.sender == arbitrumInbox, "Invalid Arbitrum messenger");
        _applyCheckpoint("Arbitrum", payload);
    }

    /// @notice Apply a checkpoint arriving from Zora
    function applyCheckpointFromZora(bytes calldata payload) external {
        require(msg.sender == zoraMessenger, "Invalid Zora messenger");
        _applyCheckpoint("Zora", payload);
    }

    /// @notice Apply a checkpoint from L1 BurnCollector
    function applyCheckpointFromL1(bytes calldata payload) external {
        require(msg.sender == l1BurnCollector, "Invalid L1 BurnCollector");
        _applyCheckpoint("L1", payload);
    }

    /// @notice Award points directly (testing/L1 burns). Only callable by owner.
    function directAward(
        uint256 tokenId,
        uint256 amount,
        string calldata source
    ) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        pointsManager.addPoints(tokenId, amount, source);
        emit DirectPointsAwarded(tokenId, amount, source);
    }

    /// @notice Register or update an eligible L1 asset and its base value (for testing / configuration)
    function setEligibleL1Asset(address asset, uint256 baseValue) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        pointsManager.addEligibleL1Asset(asset, baseValue);
    }

    /// @notice Set L1 BurnCollector address
    function setL1BurnCollector(address _collector) external onlyOwner {
        l1BurnCollector = _collector;
    }

    /// @notice Transfer ownership of PointsManager to a new owner
    function transferPointsManagerOwnership(address newOwner) external onlyOwner {
        (bool success, ) = address(pointsManager).call(abi.encodeWithSignature("transferOwnership(address)", newOwner));
        require(success, "Transfer failed");
    }

    /// @notice Update month weighting curve in PointsManager
    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        pointsManager.setMonthWeights(weights);
    }

    /// @notice Forward messenger configuration to PointsManager if needed
    function setPointsManagerMessengers(
        address base,
        address optimism,
        address arbitrum,
        address zora
    ) external onlyOwner {
        pointsManager.setMessengers(base, optimism, arbitrum, zora);
    }

    /// @dev Shared decode/apply logic for checkpoint payloads
    function _applyCheckpoint(string memory chain, bytes calldata payload) internal {
        (
            uint256[] memory tokenIds,
            uint256[] memory amounts,
            string[] memory sources
        ) = abi.decode(payload, (uint256[], uint256[], string[]));

        uint256 length = tokenIds.length;
        require(length == amounts.length, "Length mismatch");
        if (sources.length > 0) {
            require(sources.length == length, "Source length mismatch");
        }

        uint256 total;
        for (uint256 i = 0; i < length; i++) {
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            string memory appliedSource = sources.length == 0 ? chain : sources[i];
            pointsManager.addPoints(tokenIds[i], amount, appliedSource);
            total += amount;
        }

        emit CheckpointApplied(chain, length, total);
    }
}
