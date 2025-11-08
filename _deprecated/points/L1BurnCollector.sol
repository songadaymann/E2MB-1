// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPointsAggregator.sol";

/// @title L1BurnCollector
/// @notice Collects burns of eligible NFTs/ERC20s on L1 and checkpoints points to PointsAggregator
/// @dev Symmetric to L2 collectors but without bridging; direct local checkpoints
contract L1BurnCollector is Ownable, IERC721Receiver {
    IPointsAggregator public immutable aggregator;

    // Points accumulation per address (local tracking before checkpoint)
    mapping(address => uint256) public accumulatedPoints;

    // Eligible assets: ERC-721/1155/ERC20 contracts and their base values
    mapping(address => uint256) public eligibleAssets; // asset => baseValue

    // Month weights (January = index 0 = 1.0, December = index 11 = 0.60)
    uint256[12] public monthWeights;

    bool public paused;

    event BurnRecorded(
        address indexed burner,
        address indexed assetContract,
        uint256 tokenIdOrAmount,
        uint256 pointsEarned,
        uint256 month,
        uint256 timestamp
    );

    event CheckpointSent(
        uint256[] tokenIds,
        uint256[] pointsDeltas,
        uint256 totalPoints
    );

    event AssetAdded(address indexed assetContract, uint256 baseValue);
    event AssetRemoved(address indexed assetContract);

    constructor(address _aggregator) Ownable(msg.sender) {
        aggregator = IPointsAggregator(_aggregator);

        // Initialize default month weights
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    }

    /// @notice Burn an ERC-721 token for points
    function burnERC721(address nftContract, uint256 tokenId, uint256 msongTokenId) external {
        require(!paused, "Paused");
        require(eligibleAssets[nftContract] > 0, "Asset not eligible");

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        // Burn by sending to burn address (0x000...dead)
        IERC721(nftContract).transferFrom(address(this), address(0xdead), tokenId);

        uint256 pointsEarned = calculatePoints(eligibleAssets[nftContract]);
        accumulatedPoints[msg.sender] += pointsEarned;

        emit BurnRecorded(msg.sender, nftContract, tokenId, pointsEarned, _getCurrentMonth(), block.timestamp);
    }

    /// @notice Burn ERC-1155 tokens for points
    function burnERC1155(address tokenContract, uint256 tokenId, uint256 amount, uint256 msongTokenId) external {
        require(!paused, "Paused");
        require(eligibleAssets[tokenContract] > 0, "Asset not eligible");

        IERC1155(tokenContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        // Burn by sending to burn address
        IERC1155(tokenContract).safeTransferFrom(address(this), address(0xdead), tokenId, amount, "");

        uint256 pointsEarned = calculatePoints(eligibleAssets[tokenContract] * amount);
        accumulatedPoints[msg.sender] += pointsEarned;

        emit BurnRecorded(msg.sender, tokenContract, amount, pointsEarned, _getCurrentMonth(), block.timestamp);
    }

    /// @notice Burn ERC-20 tokens for points
    function burnERC20(address tokenContract, uint256 amount, uint256 msongTokenId) external {
        require(!paused, "Paused");
        require(eligibleAssets[tokenContract] > 0, "Asset not eligible");

        // IERC20(tokenContract).transferFrom(msg.sender, address(this), amount);
        // Burn by sending to burn address
        // IERC20(tokenContract).transfer(address(0xdead), amount);

        uint256 pointsEarned = calculatePoints(eligibleAssets[tokenContract] * amount);
        accumulatedPoints[msg.sender] += pointsEarned;

        emit BurnRecorded(msg.sender, tokenContract, amount, pointsEarned, _getCurrentMonth(), block.timestamp);
    }

    /// @notice Checkpoint accumulated points to PointsAggregator (manual for testing)
    /// TODO: Implement proper mapping iteration or event-based collection
    function checkpoint(uint256[] calldata tokenIds, uint256[] calldata deltas, string[] calldata sources) external onlyOwner {
    require(!paused, "Paused");
    require(tokenIds.length == deltas.length && deltas.length == sources.length, "Length mismatch");

    uint256 totalPoints;
    for (uint256 i = 0; i < tokenIds.length; i++) {
    totalPoints += deltas[i];
    }

        if (tokenIds.length > 0) {
            aggregator.applyCheckpointFromL1(abi.encode(tokenIds, deltas, sources));

            // Reset accumulations (assuming one token per burner for now)
            // TODO: Implement proper per-token accumulation
            // For now, just reset all since this is testing

            emit CheckpointSent(tokenIds, deltas, totalPoints);
        }
    }

    /// @notice Calculate points with month weighting
    function calculatePoints(uint256 basePoints) internal view returns (uint256) {
        uint256 month = _getCurrentMonth();
        return (basePoints * monthWeights[month]) / 100;
    }

    /// @notice Get current month (0-11) from block.timestamp
    function _getCurrentMonth() internal view returns (uint256) {
        // Simplified: extract month from timestamp
        // TODO: proper UTC calendar math
        uint256 timestamp = block.timestamp;
        // Placeholder: assume Jan (0) for now
        return 0;
    }

    // --- ADMIN ---

    function addEligibleAsset(address asset, uint256 baseValue) external onlyOwner {
        eligibleAssets[asset] = baseValue;
        emit AssetAdded(asset, baseValue);
    }

    function removeEligibleAsset(address asset) external onlyOwner {
        delete eligibleAssets[asset];
        emit AssetRemoved(asset);
    }

    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    // ERC-721 receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
