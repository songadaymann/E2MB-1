# Auction Contracts

## Overview
This directory will contain the MATT (Market-Aware Truth-Telling) auction contracts for the Millennium Song NFT collection.

## Planned Contracts

### MATTAuction.sol (TBD)
- On-chain bid acceptance and commitment
- Revenue-maximizing clearing set selection
- Uniform clearing price calculation
- Winner selection and minting coordination

### Key Features
- Accepts on-chain bids (commitments)
- Selects revenue-maximizing clearing set
- Charges uniform clearing price to all winners
- Calls `mint(to)` on MillenniumSong ERC-721
- Emits `Cleared(totalSupply, clearingPrice)`

### Integration Points
- Must call `MillenniumSong.mint(address to)` for each winner
- Restricted minting: only auction contract can mint (pre-finalize)
- No hard min/max supply caps (determined by clearing set)

## References
- See agent.md §3 for MATT auction spec
- Post-auction: triggers VRF randomness request
