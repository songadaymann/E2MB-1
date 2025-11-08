// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title BurnCollectorArbitrum
/// @notice Collects burns of eligible NFTs on Arbitrum and sends points to L1
/// @dev Uses Arbitrum's canonical L2→L1 messenger for trust-minimized bridging
contract BurnCollectorArbitrum is Ownable, IERC721Receiver {
    
    // Arbitrum Sepolia Testnet: 0x0000000000000000000000000000000000000064
    // Arbitrum One Mainnet: 0x0000000000000000000000000000000000000064
    address public constant ARB_SYS = 0x0000000000000000000000000000000000000064;
    
    address public l1Target; // MillenniumSong contract on L1
    
    // Points accumulation per address
    mapping(address => uint256) public accumulatedPoints;
    
    // Eligible NFT contracts and their base values
    mapping(address => uint256) public eligibleAssets;
    
    // Month weights
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
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    }
    
    function addEligibleAsset(address nftContract, uint256 baseValue) external onlyOwner {
        require(nftContract != address(0), "Invalid address");
        require(baseValue > 0, "Base value must be > 0");
        eligibleAssets[nftContract] = baseValue;
        emit AssetAdded(nftContract, baseValue);
    }
    
    function removeEligibleAsset(address nftContract) external onlyOwner {
        delete eligibleAssets[nftContract];
        emit AssetRemoved(nftContract);
    }
    
    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }
    
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
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
    
    function burnToken(address nftContract, uint256 tokenId) external {
        require(!paused, "Burns paused");
        require(eligibleAssets[nftContract] > 0, "Asset not eligible");
        
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        _recordBurn(msg.sender, nftContract, tokenId);
    }
    
    function _recordBurn(address burner, address nftContract, uint256 tokenId) internal {
        uint256 baseValue = eligibleAssets[nftContract];
        uint256 month = _getCurrentMonth();
        uint256 weight = monthWeights[month];
        
        uint256 points = (baseValue * weight) / 100;
        
        accumulatedPoints[burner] += points;
        
        emit BurnRecorded(burner, nftContract, tokenId, points, month, block.timestamp);
    }
    
    /// @notice Send accumulated points to L1 (Arbitrum uses different messenger)
    function checkpoint(address[] calldata addresses) external payable {
        require(addresses.length > 0, "Empty addresses");
        require(addresses.length <= 100, "Too many addresses");
        
        uint256[] memory pointsDeltas = new uint256[](addresses.length);
        uint256 totalPoints;
        
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 points = accumulatedPoints[addresses[i]];
            pointsDeltas[i] = points;
            totalPoints += points;
            
            delete accumulatedPoints[addresses[i]];
        }
        
        bytes memory payload = abi.encode(addresses, pointsDeltas);
        
        // Arbitrum uses ArbSys.sendTxToL1
        IArbSys(ARB_SYS).sendTxToL1(l1Target, payload);
        
        emit CheckpointSent(addresses, pointsDeltas, totalPoints);
    }
    
    function _getCurrentMonth() internal view returns (uint256) {
        uint256 daysFromEpoch = block.timestamp / 1 days;
        uint256 approxMonth = (daysFromEpoch % 365) / 30;
        return approxMonth > 11 ? 11 : approxMonth;
    }
    
    function setL1Target(address _l1Target) external onlyOwner {
        require(_l1Target != address(0), "Invalid address");
        l1Target = _l1Target;
    }
}

/// @notice Arbitrum system contract interface
interface IArbSys {
    function sendTxToL1(address destination, bytes calldata data)
        external
        payable
        returns (uint256);
}
