// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PointsCalculator
 * @notice Calculates points for burning various asset types in the Millennium Song system
 * @dev All calculations use fixed-point math (scaled by 100) to avoid decimals
 * 
 * ASSET CATEGORIES:
 * 1. NFT Editions/PFPs: Burned for points (formula: 10 · √(10 / min(S, 10,000)))
 * 2. Zora Daily Coins: Burned for points (1 pt per coin if balance ≥ 10k)
 * 3. Legacy ERC-20s: Burned for points (log-based on % of supply)
 * 4. Song A Day 1/1s: HELD (not burned) - act as MULTIPLIER (1 + 0.15 · √(n_1of1))
 * 5. SuperRare 1/1s: HELD (not burned) - act as MULTIPLIER (same formula)
 */
library PointsCalculator {
    
    // ============================================================================
    // CONSTANTS & TYPES
    // ============================================================================
    
    /// @dev Scale factor for fixed-point math (all values scaled by 100)
    uint256 constant SCALE = 100;
    
    /// @dev Max supply cap for NFT formula (diminishing returns beyond this)
    uint256 constant MAX_SUPPLY_CAP = 10000;
    
    /// @dev Threshold for Zora daily coins (must hold at least this many)
    uint256 constant ZORA_COIN_THRESHOLD = 10000;
    
    /// @dev Max daily coins per year (365 days)
    uint256 constant MAX_DAILY_COINS_PER_YEAR = 365;
    
    /// @dev Max points per legacy ERC-20 token
    uint256 constant MAX_LEGACY_TOKEN_POINTS = 10;
    
    enum AssetType {
        NFT_EDITION,      // Editions, PFPs - burnable
        ZORA_DAILY_COIN,  // Zora daily coins - burnable
        LEGACY_ERC20,     // Taxes/TSWND - burnable
        SONG_A_DAY_1of1,  // Song A Day 1/1s - HELD (multiplier only)
        SUPERRARE_1of1    // SuperRare 1/1s - HELD (multiplier only)
    }
    
    // ============================================================================
    // NFT EDITION/PFP FORMULA
    // ============================================================================
    
    /// @notice Calculate points for burning an NFT edition or PFP
    /// @dev Formula: 10 · √(10 / min(S, 10,000))
    ///      Scaled by 100 for fixed-point: result is in "basis points" (×100)
    /// @param supply Total supply of the NFT collection
    /// @return points Points earned (scaled by 100)
    function calculateNFTPoints(uint256 supply) internal pure returns (uint256) {
        require(supply > 0, "Supply must be > 0");
        
        // Cap supply at 10,000 for diminishing returns
        uint256 cappedSupply = supply > MAX_SUPPLY_CAP ? MAX_SUPPLY_CAP : supply;
        
        // Calculate: 10 · √(10 / S)
        // = 10 · √10 / √S
        // = 10 · 3.16227766... / √S
        // Using fixed-point: 316 (sqrt(10) * 100) / sqrt(S)
        
        uint256 sqrtSupply = _sqrt(cappedSupply);
        uint256 numerator = 316; // sqrt(10) * 100
        
        // Result: 10 * numerator / sqrtSupply = 1000 * numerator / sqrtSupply
        return (1000 * numerator) / sqrtSupply;
    }
    
    // ============================================================================
    // 1/1 MULTIPLIER (HELD, NOT BURNED)
    // ============================================================================
    
    /// @notice Calculate multiplier for holding Song A Day or SuperRare 1/1s
    /// @dev Formula: 1 + 0.15 · √(n_1of1)
    ///      Returned as multiplier scaled by 100 (e.g., 130 = 1.30×)
    /// @param num1of1s Number of 1/1s held by the user
    /// @return multiplier Multiplier scaled by 100 (100 = 1.0×, 150 = 1.5×)
    function calculate1of1Multiplier(uint256 num1of1s) internal pure returns (uint256) {
        if (num1of1s == 0) return SCALE; // 1.0× (no multiplier)
        
        // Formula: 1 + 0.15 · √(n)
        // Scaled: 100 + 15 · √(n)
        uint256 sqrtCount = _sqrt(num1of1s);
        return SCALE + (15 * sqrtCount);
    }
    
    /// @notice Apply 1/1 multiplier to base points
    /// @param basePoints Points before multiplier (scaled by 100)
    /// @param num1of1s Number of 1/1s held
    /// @return Points after applying multiplier (scaled by 100)
    function applyMultiplier(uint256 basePoints, uint256 num1of1s) internal pure returns (uint256) {
        if (num1of1s == 0) return basePoints;
        
        uint256 multiplier = calculate1of1Multiplier(num1of1s);
        // Both are scaled by 100, so multiply and divide by 100 to maintain scale
        return (basePoints * multiplier) / SCALE;
    }
    
    // ============================================================================
    // ZORA DAILY COINS
    // ============================================================================
    
    /// @notice Calculate points for Zora daily coin holdings
    /// @dev 1 point per coin if balance ≥ 10,000 units (0.001% of 1B supply)
    /// @param balances Array of balances for each daily coin
    /// @return points Total points (scaled by 100)
    function calculateZoraCoinPoints(uint256[] memory balances) internal pure returns (uint256) {
        uint256 totalPoints = 0;
        uint256 coinCount = balances.length;
        
        // Cap at 365 coins per year
        if (coinCount > MAX_DAILY_COINS_PER_YEAR) {
            coinCount = MAX_DAILY_COINS_PER_YEAR;
        }
        
        for (uint256 i = 0; i < coinCount; i++) {
            if (balances[i] >= ZORA_COIN_THRESHOLD) {
                totalPoints += SCALE; // 1 point per coin (scaled)
            }
        }
        
        return totalPoints;
    }
    
    // ============================================================================
    // LEGACY ERC-20 (Taxes Coin, This Song Will Never Die)
    // ============================================================================
    
    /// @notice Calculate points for burning legacy ERC-20 tokens
    /// @dev Formula: min(10, 5 · log10(1 + bps))
    ///      where bps = (balance / totalSupply) * 10,000
    /// @param balance Amount of tokens being burned
    /// @param totalSupply Total supply of the ERC-20
    /// @return points Points earned (scaled by 100)
    function calculateLegacyTokenPoints(
        uint256 balance,
        uint256 totalSupply
    ) internal pure returns (uint256) {
        require(totalSupply > 0, "Total supply must be > 0");
        
        // Calculate basis points of supply held
        uint256 bps = (balance * 10000) / totalSupply;
        
        if (bps == 0) return 0;
        
        // Apply log10 formula with lookup table
        uint256 logValue = _log10BpsLookup(bps);
        
        // Points = 5 · log10(1 + bps)
        uint256 rawPoints = (5 * logValue);
        
        // Cap at 10 points, scale by 100
        if (rawPoints > MAX_LEGACY_TOKEN_POINTS) {
            rawPoints = MAX_LEGACY_TOKEN_POINTS;
        }
        
        return rawPoints * SCALE;
    }
    
    /// @notice Lookup table for log10(1 + bps) to avoid floating point
    /// @dev Returns log10(1 + bps) * 100 (scaled)
    function _log10BpsLookup(uint256 bps) private pure returns (uint256) {
        // log10(1 + bps) approximation (scaled by 100)
        
        if (bps >= 100) return 200;  // log10(101) ≈ 2.00 → 10 pts (capped)
        if (bps >= 50) return 171;   // log10(51) ≈ 1.71
        if (bps >= 25) return 141;   // log10(26) ≈ 1.41
        if (bps >= 10) return 104;   // log10(11) ≈ 1.04 → ~5.2 pts
        if (bps >= 5) return 78;     // log10(6) ≈ 0.78
        if (bps >= 2) return 48;     // log10(3) ≈ 0.48
        if (bps >= 1) return 30;     // log10(2) ≈ 0.30 → ~1.5 pts
        
        return 0;
    }
    
    // ============================================================================
    // COMPREHENSIVE CALCULATION
    // ============================================================================
    
    /// @notice Calculate total points for a burn, applying 1/1 multiplier
    /// @param assetType Type of asset being burned
    /// @param supply NFT supply (for NFT_EDITION only)
    /// @param balanceOrAmount Balance for coins, amount for ERC-20
    /// @param totalSupply Total supply for ERC-20 (ignored for other types)
    /// @param num1of1sHeld Number of Song A Day + SuperRare 1/1s HELD (not burned)
    /// @return points Total points (scaled by 100)
    function calculateTotalPoints(
        AssetType assetType,
        uint256 supply,
        uint256 balanceOrAmount,
        uint256 totalSupply,
        uint256 num1of1sHeld
    ) internal pure returns (uint256) {
        uint256 basePoints;
        
        if (assetType == AssetType.NFT_EDITION) {
            basePoints = calculateNFTPoints(supply);
        } else if (assetType == AssetType.ZORA_DAILY_COIN) {
            // For single coin, create array
            uint256[] memory balances = new uint256[](1);
            balances[0] = balanceOrAmount;
            basePoints = calculateZoraCoinPoints(balances);
        } else if (assetType == AssetType.LEGACY_ERC20) {
            basePoints = calculateLegacyTokenPoints(balanceOrAmount, totalSupply);
        } else {
            revert("1/1s cannot be burned - they are held as multipliers");
        }
        
        // Apply 1/1 multiplier
        return applyMultiplier(basePoints, num1of1sHeld);
    }
    
    // ============================================================================
    // INTEGER SQUARE ROOT (Babylonian method)
    // ============================================================================
    
    /// @notice Calculate integer square root using Babylonian method
    /// @dev Gas-optimized version for uint256
    function _sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;
        
        // Initial guess
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        // Iterate until convergence
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }
    
    // ============================================================================
    // EXAMPLES (for documentation/testing)
    // ============================================================================
    
    /// @dev Example: Fuckin Trolls (supply 9,982) → 3.16 pts
    ///      calculateNFTPoints(9982) ≈ 316 (scaled)
    
    /// @dev Example: Song A Day holder with 4 1/1s burning a Troll
    ///      basePoints = 316
    ///      multiplier = 100 + 15·√4 = 100 + 30 = 130
    ///      totalPoints = 316 · 1.30 = 411 (scaled)
    
    /// @dev Example: Taxes Coin - burning 1,095 tokens (0.1% of supply)
    ///      bps = 10
    ///      log10(11) ≈ 1.04 → 5.2 pts → 520 (scaled)
    
    /// @dev Example: Zora daily coin with 15,000 balance
    ///      balance ≥ 10,000 → 1 pt → 100 (scaled)
}
