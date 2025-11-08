# Millennium Song - On-chain NFT Countdown System

An experimental ERC-721 collection where each token shows an animated countdown to its reveal year, with dynamic ranking based on a cross-chain points system.

## Contract Organization

### Core Contracts

- **[`src/core/MillenniumSong.sol`](src/core/MillenniumSong.sol)** - Main ERC-721 contract with modular renderer system
- **[`SongAlgorithm.sol`](SongAlgorithm.sol)** - Pure Solidity music generation library (V3 lead + V2 bass, phrase grammar, tonnetz)

### Renderers (Modular Architecture)

- **[`src/render/pre/CountdownRenderer.sol`](src/render/pre/CountdownRenderer.sol)** - 12-digit animated countdown odometer for pre-reveal tokens
- **[`src/render/post/MusicRenderer.sol`](src/render/post/MusicRenderer.sol)** - Musical staff renderer for post-reveal tokens
- **[`src/render/post/SvgMusicGlyphs.sol`](src/render/post/SvgMusicGlyphs.sol)** - SVG music symbol library (treble clef, notes, rests, etc.)
- **[`src/render/post/NotePreview.sol`](src/render/post/NotePreview.sol)** - Preview utility for music rendering
- **[`src/render/IRenderTypes.sol`](src/render/IRenderTypes.sol)** - Shared interface types

### Legacy Contracts (Reference)

- **[`src/CountdownNFT.sol`](src/CountdownNFT.sol)** - Original monolithic countdown NFT
- **[`src/CountdownNFTLite.sol`](src/CountdownNFTLite.sol)** - Simplified version for testing

## What's Working ✅

- **Complete countdown system** with 12-digit animated odometer
- **Time-synchronized animations** that persist across browser refreshes
- **Dynamic ranking** based on points system (higher points = earlier reveal)
- **Exact UTC Jan-1 boundary calculations** with leap year handling
- **Rank-based visual styling** (opacity gradients based on queue position)
- **Full test coverage** (20/20 tests passing)
- **Sepolia deployment** working with live minting

## What's Stubs/TODO ⚠️

- **Cross-chain Points system** (L2 burn collectors, message passing) - core logic exists but bridge integration needed
- **VRF randomness** for base queue permutation - placeholder uses tokenId
- **MATT auction system** for initial token distribution
- **Finalization/immutability** system with freeze periods
- **Audio generation** for revealed tokens (minimal WAV/PCM)
- **Full post-reveal music rendering** - staff drawing exists but needs integration with SongAlgorithm
- **ERC-2981 royalty system** setup

## Recent Sepolia Deployment

Latest modular deployment: `0xD2bE6D28dB2520bE54329BA9Cddf01bb9339c060`
- 5 tokens minted with point spread (0, 3, 12, 50, 250 points)
- Demonstrates rank-based queue ordering

## Foundry Toolkit

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

Documentation: https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Deploy the modular MillenniumSong to Sepolia:
```shell
$ source .env && forge script script/DeployMillenniumSong.s.sol --fork-url $SEPOLIA_RPC_URL --broadcast
```

Deploy legacy CountdownNFT:
```shell
$ source .env && forge script script/DeployCountdown.s.sol --fork-url $SEPOLIA_RPC_URL --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
