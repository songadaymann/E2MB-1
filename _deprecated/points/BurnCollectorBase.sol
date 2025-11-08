// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title BurnCollectorBase
/// @notice Collects burns of eligible NFTs on Base and sends points to L1
/// @dev Uses Base's canonical L2→L1 messenger for trust-minimized bridging
contract BurnCollectorBase is Ownable, IERC721Receiver {
    
    // Base Sepolia Testnet messenger: 0x4200000000000000000000000000000000000007
    // Base Mainnet messenger: 0x4200000000000000000000000000000000000007
    address public constant BASE_MESSENGER = 0x4200000000000000000000000000000000000007;
    
    address public l1Target; // MillenniumSong contract on L1
    
    // Points accumulation per address (local tracking before checkpoint)
    mapping(address => uint256) public accumulatedPoints;
    
    // Eligible NFT contracts and their base values
    mapping(address => uint256) public eligibleAssets; // nftContract => baseValue
    
    // Month weights (January = index 0 = 1.0, December = index 11 = 0.60)
    uint256[12] public monthWeights;
    
    bool public paused;
    
    event BurnRecorded(
        address indexed burner,
        address indexed nftContract,
        uint256 tokenId,
        uint256 pointsEarned,
        uint256 month,
        uint256 timestamp
    );
    
    event CheckpointSent(
        address[] addresses,
        uint256[] pointsDeltas,
        uint256 totalPoints
    );
    
    event AssetAdded(address indexed nftContract, uint256 baseValue);
    event AssetRemoved(address indexed nftContract);
    
    constructor(address _l1Target) Ownable(msg.sender) {
        l1Target = _l1Target;
        
        // Initialize month weights (scaled by 100 for precision)
        // Jan=100, Feb=95, Mar=92, Apr=88, May=85, Jun=82, Jul=78, Aug=75, Sep=72, Oct=68, Nov=65, Dec=60
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    }
    
    /// @notice Add an eligible NFT contract with its base point value
    function addEligibleAsset(address nftContract, uint256 baseValue) external onlyOwner {
        require(nftContract != address(0), "Invalid address");
        require(baseValue > 0, "Base value must be > 0");
        eligibleAssets[nftContract] = baseValue;
        emit AssetAdded(nftContract, baseValue);
    }
    
    /// @notice Remove an eligible NFT contract
    function removeEligibleAsset(address nftContract) external onlyOwner {
        delete eligibleAssets[nftContract];
        emit AssetRemoved(nftContract);
    }
    
    /// @notice Update month weights
    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }
    
    /// @notice Pause/unpause burns
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    /// @notice Handle incoming NFT transfers (burn mechanism)
    /// @dev NFTs sent here are considered burned
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        require(!paused, "Burns paused");
        require(eligibleAssets[msg.sender] > 0, "Asset not eligible");
        
        _recordBurn(from, msg.sender, tokenId);
        
        return IERC721Receiver.onERC721Received.selector;
    }
    
    /// @notice Alternative: explicit burn function (for assets with burn())
    /// @param nftContract The NFT contract to burn from
    /// @param tokenId The token to burn
    function burnToken(address nftContract, uint256 tokenId) external {
        require(!paused, "Burns paused");
        require(eligibleAssets[nftContract] > 0, "Asset not eligible");
        
        // Transfer to this contract (acts as burn)
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        _recordBurn(msg.sender, nftContract, tokenId);
    }
    
    /// @notice Internal burn recording and points calculation
    function _recordBurn(address burner, address nftContract, uint256 tokenId) internal {
        // Calculate points
        uint256 baseValue = eligibleAssets[nftContract];
        uint256 month = _getCurrentMonth();
        uint256 weight = monthWeights[month];
        
        // Points = baseValue × weight / 100
        uint256 points = (baseValue * weight) / 100;
        
        // Accumulate for this address
        accumulatedPoints[burner] += points;
        
        emit BurnRecorded(burner, nftContract, tokenId, points, month, block.timestamp);
    }
    
    /// @notice Send accumulated points to L1 (anyone can call)
    /// @param addresses List of addresses to checkpoint
    function checkpoint(address[] calldata addresses) external {
        require(addresses.length > 0, "Empty addresses");
        require(addresses.length <= 100, "Too many addresses"); // Gas limit
        
        uint256[] memory pointsDeltas = new uint256[](addresses.length);
        uint256 totalPoints;
        
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 points = accumulatedPoints[addresses[i]];
            pointsDeltas[i] = points;
            totalPoints += points;
            
            // Reset accumulated points after checkpointing
            delete accumulatedPoints[addresses[i]];
        }
        
        // Encode payload for L1
        bytes memory payload = abi.encode(addresses, pointsDeltas);
        
        // Send via Base messenger
        ICrossDomainMessenger(BASE_MESSENGER).sendMessage(
            l1Target,
            payload,
            1_000_000 // Gas limit for L1 execution
        );
        
        emit CheckpointSent(addresses, pointsDeltas, totalPoints);
    }
    
    /// @notice Get current month (0-11)
    function _getCurrentMonth() internal view returns (uint256) {
        // Simplified: extract month from timestamp
        // In production, use proper UTC calendar math or oracle
        uint256 daysFromEpoch = block.timestamp / 1 days;
        uint256 approxMonth = (daysFromEpoch % 365) / 30; // Rough approximation
        return approxMonth > 11 ? 11 : approxMonth;
    }
    
    /// @notice Update L1 target address
    function setL1Target(address _l1Target) external onlyOwner {
        require(_l1Target != address(0), "Invalid address");
        l1Target = _l1Target;
    }
}

/// @notice Minimal interface for Base's CrossDomainMessenger
interface ICrossDomainMessenger {
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}
