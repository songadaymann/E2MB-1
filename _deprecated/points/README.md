# Points System Contracts

## Overview
Cross-chain points system for dynamic queue re-ordering. Burns on L2s (Base/Optimism/Arbitrum) earn points that immediately re-rank tokens on L1.

## Planned Contracts

### L1 Aggregator (L1PointsAggregator.sol) - TBD
**Location:** Ethereum L1

**Key State:**
- `mapping(uint256 => uint256) points` - Per-token points ledger
- Canonical source of truth for all points

**Functions:**
- `applyCheckpointFromBase(bytes payload)` - Accept batched points from Base
- `applyCheckpointFromOptimism(bytes payload)` - Accept from Optimism
- `applyCheckpointFromArbitrum(bytes payload)` - Accept from Arbitrum
- `pointsOf(uint256 tokenId)` - Query points
- `currentRankOf(uint256 tokenId)` - Compute rank from points

**Events:**
- `PointsApplied(uint256 indexed tokenId, uint256 delta, uint8 month, uint256 newTotal)`
- `RankChanged(uint256 indexed tokenId, uint32 oldRank, uint32 newRank)`
- `CheckpointApplied(bytes32 indexed l2BlockHash, string chain, uint256 count)`

### L2 Burn Collectors (per chain) - TBD

**BurnCollectorBase.sol** - Base chain
**BurnCollectorOptimism.sol** - Optimism
**BurnCollectorArbitrum.sol** - Arbitrum

**Key Functions:**
- `recordBurn(assetId, owner, meta)` - Record on-chain burns
- Maintain per-address accumulated points (L2-local)
- Emit `BurnRecorded(owner, assetId, value, timestamp)`
- Periodic checkpoint batching to L1

### Point Accrual Rules (TBD - exact values)
**Monthly weighting** (within calendar year):
- Earlier months earn more points
- Example: `weight(Jan)=1.0, Feb=0.95, ..., Dec=0.60`
- Existing points DO NOT decay (weight affects new points only)

**Scoring formula:**
```
Points = baseValue(asset) × monthWeight(burnMonth) × optionalMultipliers
```

### Bridge Architecture
- **Trust-minimized:** Uses canonical L2→L1 message passing
- **Optimism:** L2ToL1MessagePasser
- **Arbitrum:** Outbox
- **Base:** Canonical messenger
- **Finality:** Ranking updates when L2 message finalized

### Rank Computation (implemented in L1 Aggregator)
**Ordering logic:**
1. All tokens with points > 0, sorted by:
   - Points DESC
   - Tie → baseQueueIndex ASC (VRF order)
   - Tie → tokenId ASC
2. All tokens with points == 0, sorted by tokenId ASC

## Integration with Core
- Points changes trigger immediate re-rank (view-computed)
- Rank determines `revealYear(rank) = startYear + rank`
- `isRevealed(tokenId)` depends on current rank

## References
- See agent.md §5 for complete Points system spec
- See agent.md §5.4 for rank computation algorithm
