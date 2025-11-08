// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IE2MB.sol";
import "../interfaces/IPointsManager.sol";

/**
 * @title PointsManager
 * @notice Manages points and ranking for EveryTwoMillionBlocks NFT
 * @dev Separated from NFT contract to stay under 24KB size limit
 */
contract PointsManager is IPointsManager, Ownable {
    
    // --- STATE ---
    
    /// @notice Reference to the NFT contract
    IE2MB public immutable nft;
    
    /// @notice Points per token
    mapping(uint256 => uint256) public points;
    
    /// @notice Month weights for points calculation (scaled by 100)
    /// Jan=100, Feb=95, Mar=92, Apr=88, May=85, Jun=82, Jul=78, Aug=75, Sep=72, Oct=68, Nov=65, Dec=60
    uint256[12] public monthWeights;
    
    // --- CROSS-CHAIN MESSENGERS (L2 → L1) ---
    address public baseMessenger;
    address public optimismMessenger;
    address public arbitrumInbox;
    address public zoraMessenger;
    
    // --- L1 BURN HANDLING ---
    mapping(address => uint256) public eligibleL1Assets;
    
    // --- EVENTS ---
    
    event PointsApplied(
        uint256 indexed tokenId,
        uint256 pointsDelta,
        uint256 newTotal,
        string source
    );
    
    event CheckpointReceived(
        string indexed chain,
        uint256 addressCount,
        uint256 totalPoints
    );
    
    event MessengersUpdated(
        address base,
        address optimism,
        address arbitrum,
        address zora
    );
    
    // --- CONSTRUCTOR ---
    
    constructor(address _nft) Ownable(msg.sender) {
        nft = IE2MB(_nft);
        
        // Initialize default month weights
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
        
        // Initialize default messenger addresses (mainnet)
        baseMessenger = 0x4200000000000000000000000000000000000007;
        optimismMessenger = 0x4200000000000000000000000000000000000007;
        zoraMessenger = 0x4200000000000000000000000000000000000007;
    }
    
    // --- VIEWS ---
    
    /// @notice Get points for a token
    function pointsOf(uint256 tokenId) external view override returns (uint256) {
        return points[tokenId];
    }
    
    /// @notice Get current rank for a token (0-indexed)
    /// @dev O(n) algorithm - acceptable for supply ≤ 1000
    function currentRankOf(uint256 tokenId) external view override returns (uint256) {
        uint256 totalSupply = nft.totalMinted();
        require(tokenId > 0 && tokenId <= totalSupply, "Token does not exist");
        
        return _getCurrentRank(tokenId, totalSupply);
    }
    
    /// @dev Internal ranking algorithm
    /// Ordering: points DESC → basePermutation ASC → tokenId ASC
    /// Zero-point tokens go after all pointed tokens, ordered by tokenId
    function _getCurrentRank(uint256 tokenId, uint256 totalSupply) private view returns (uint256 rank) {
        uint256 tokenPoints = points[tokenId];
        uint256 tokenBase = nft.basePermutation(tokenId);
        
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (i == tokenId) continue;
            
            uint256 otherPoints = points[i];
            uint256 otherBase = nft.basePermutation(i);
            
            bool comesBeforeUs = false;
            
            if (otherPoints > 0 && tokenPoints > 0) {
                // Both have points: compare points, then basePermutation, then tokenId
                if (otherPoints > tokenPoints) {
                    comesBeforeUs = true;
                } else if (otherPoints == tokenPoints) {
                    if (otherBase < tokenBase) {
                        comesBeforeUs = true;
                    } else if (otherBase == tokenBase && i < tokenId) {
                        comesBeforeUs = true;
                    }
                }
            } else if (otherPoints > 0 && tokenPoints == 0) {
                // Other has points, we don't: other comes first
                comesBeforeUs = true;
            } else if (otherPoints == 0 && tokenPoints == 0) {
                // Neither has points: order by tokenId
                if (i < tokenId) {
                    comesBeforeUs = true;
                }
            }
            // else: we have points, other doesn't → we come first
            
            if (comesBeforeUs) {
                rank++;
            }
        }
    }
    
    // --- MUTATORS ---
    
    /// @notice Add points to a token (admin only)
    function addPoints(uint256 tokenId, uint256 amount, string calldata source) external override onlyOwner {
        points[tokenId] += amount;
        emit PointsApplied(tokenId, amount, points[tokenId], source);
    }
    
    /// @notice Batch set points (for migration/testing)
    function batchSetPoints(uint256[] calldata tokenIds, uint256[] calldata amounts) external onlyOwner {
        require(tokenIds.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            points[tokenIds[i]] = amounts[i];
            emit PointsApplied(tokenIds[i], amounts[i], amounts[i], "BatchSet");
        }
    }
    
    // --- CONFIGURATION ---
    
    /// @notice Set messenger addresses
    function setMessengers(
        address _base,
        address _optimism,
        address _arbitrum,
        address _zora
    ) external onlyOwner {
        baseMessenger = _base;
        optimismMessenger = _optimism;
        arbitrumInbox = _arbitrum;
        zoraMessenger = _zora;
        
        emit MessengersUpdated(_base, _optimism, _arbitrum, _zora);
    }
    
    /// @notice Set month weights
    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }
    
    /// @notice Add eligible L1 asset for burning
    function addEligibleL1Asset(address nft_, uint256 baseValue) external onlyOwner {
        eligibleL1Assets[nft_] = baseValue;
    }
    
    // --- CROSS-CHAIN CHECKPOINTS (STUBS) ---
    
    function applyCheckpointFromBase(bytes calldata) external {
        require(msg.sender == baseMessenger, "Not Base messenger");
        // Implementation TBD
    }
    
    function applyCheckpointFromOptimism(bytes calldata) external {
        require(msg.sender == optimismMessenger, "Not Optimism messenger");
        // Implementation TBD
    }
    
    function applyCheckpointFromArbitrum(bytes calldata) external {
        require(msg.sender == arbitrumInbox, "Not Arbitrum inbox");
        // Implementation TBD
    }
    
    function applyCheckpointFromZora(bytes calldata) external {
        require(msg.sender == zoraMessenger, "Not Zora messenger");
        // Implementation TBD
    }
}
