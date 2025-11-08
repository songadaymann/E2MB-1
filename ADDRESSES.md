# Deployed Addresses (Sepolia)

**Latest Deployment:** Oct 30, 2025 22:21 UTC — Fresh Points Stack + VRF v2.5 E2MB

## Points System Contracts ✅
- **PointsManager:** `0x8086be0A8aAa0c756C3729c36fCF65850fb00Cd1`
- **PointsAggregator:** `0xb311a1e74E558093c0F9057Ba740F9677362820e`
- **L1BurnCollector:** `0x75045e5d3052Fc2B065C52a8E32650A681fC32BD`
- Base ratios: 1 ERC721 ≈ 10 ERC1155 ≈ 100k ERC20 (collector normalizes ERC20 amounts by decimals)
- **LayerZero Receiver (Sepolia):** `0x90EA1d07c0d4C6bB73E94444554b0217A0FABF7D`
- **LayerZero Endpoint (Ethereum Sepolia):** `0x6EDCE65403992e310A62460808c4b910D972f10f` (Endpoint ID `40161`)

## Base (Sepolia) LayerZero Configuration
- **BaseBurnCollector:** `0x39b391df153c252e9486e7e3990b1c74289f9950`
- **LayerZero Endpoint (Base Sepolia):** `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **Endpoint ID:** `40245`
- **Base Dummy ERC721:** `0xc3032d5E67C8A67C9745943929F8DFf2410Dd9A1`
- **Base Dummy ERC1155:** `0x7EDBF92B00CB680cC083A65aD3348f40ab886FB8`
- **Base Dummy ERC20:** `0x83F7D8c70F0D4730Bbc914d76700e9D0FFcee027`
- **Song-A-Day Multiplier Source:** `SONG_A_DAY_COLLECTION_ADDRESS` (currently `0x0000000000000000000000000000000000000000` on Sepolia to disable bonus)

_Other testnet endpoint IDs (for future collectors):_
- **Optimism Sepolia (EID):** `40232`, Endpoint `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **Arbitrum Sepolia (EID):** `40231`, Endpoint `0x6EDCE65403992e310A62460808c4b910D972f10f`


## Dummy Burnable Assets
- **DummyERC721 (100k pts per burn):** `0x614FE9079021688115A8Ec29b065344C033f9740`
- **DummyERC20 (1 pt per token, decimals=18):** `0x7Ef7dF0F64A2591fd5bE9c1E88728e59CB5D362B`
- **DummyERC1155 (10k pts per copy):** `0xD2DcB326F003DC8db194C74Db2749F8C653Df6aC`

## Main Contract ✅
- **EveryTwoMillionBlocks:** `0x5D9116ee207C2bB2f378047AA506366F06D52605`
  - Name: "Every Two Million Blocks"
  - Symbol: "E2MB"
  - Fresh deploy (Oct 30 2025) wired to new points stack + VRF v2.5
  - **Rarible:** https://testnet.rarible.com/token/sepolia/0x5d9116ee207c2bb2f378047aa506366f06d52605:1

## Rendering Stack
- **SvgMusicGlyphs:** `0xd6DF883c23337B0925012Da2646a6E7bA5D9083f`
- **StaffUtils:** `0xF0ac54C0D3Fe7FCd911776F9B83C99d440cEe2F1`
- **MidiToStaff:** `0xd3bada9A75268fa43dd6F6F6891d8cfAA5DD8Ff0`
- **NotePositioning:** `0x64935B6349bfbEc5fB960EAc1e34c19539AA70C2`
- **MusicRendererOrchestrator:** `0x9EB5f4DA5Eb104dd34AAf9397B9b178AdFA2DC81`
- **AudioRenderer:** `0xF68310926327B76b102ddc5e25500A42F83DE7af`
- **SongAlgorithm:** `0xc0Da9A18f16807725dc0C6bEd7E49A2725D912A3`

## Status
✅ Points system deployed and wired (L1BurnCollector redeployed with burnERC721, all verified on Etherscan)
✅ Dummy assets deployed with eligible configurations
✅ Burn functions attempt burning or hold assets
✅ Ready for testing burns to accrue points and reorder ranks

## Commands

Mint dummy ERC721:
```bash
cast send 0x576E4ebb4eA4Ea6c2ad7760E58Eb5B745785dE01 'mint(address)' 0xAd9fDaD276AB1A430fD03177A07350CD7C61E897 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Mint dummy ERC20:
```bash
cast send 0xCC0b5B80880F8d999054E03F3e13466995ABCe86 'mint(address,uint256)' 0xAd9fDaD276AB1A430fD03177A07350CD7C61E897 1000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Mint dummy ERC1155:
```bash
cast send 0xB4264Bb1B121B4094Df2ac0Bb91ab7a4F845B635 'mintEdition(address,uint256,uint256)' 0xAd9fDaD276AB1A430fD03177A07350CD7C61E897 1 100 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Burn ERC721 (tokenId, E2MB tokenId):
```bash
cast send 0x1dd4c391062990C31FF5d5184Cd654AbB30903bd 'burnERC721(address,uint256,uint256)' 0x576E4ebb4eA4Ea6c2ad7760E58Eb5B745785dE01 0 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Burn ERC20 (amount, E2MB tokenId):
```bash
cast send 0x1dd4c391062990C31FF5d5184Cd654AbB30903bd 'burnERC20(address,uint256,uint256)' 0xCC0b5B80880F8d999054E03F3e13466995ABCe86 50 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Burn ERC1155 (id, amount, E2MB tokenId):
```bash
cast send 0x1dd4c391062990C31FF5d5184Cd654AbB30903bd 'burnERC1155(address,uint256,uint256,uint256)' 0xB4264Bb1B121B4094Df2ac0Bb91ab7a4F845B635 1 10 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Check points:
```bash
cast call 0xb890dFc6010E457C872ABAfd344df5517742D4e9 'getPoints(uint256)' 1 --rpc-url $SEPOLIA_RPC_URL
```

Check rank:
```bash
cast call 0xb890dFc6010E457C872ABAfd344df5517742D4e9 'currentRankOf(uint256)' 1 --rpc-url $SEPOLIA_RPC_URL
```

View E2MB metadata:
```bash
cast call 0xdCEC22d76590bCd0E8935c8Aaf537F7E750a1740 'tokenURI(uint256)' 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## Previous Deployments (Archived)

### Session 2 (Oct 9 afternoon) - Working MillenniumSong
- MillenniumSong: `0xA62ADf47908fe4fdeD9B3cA84884910c5400aB32`
- Token #1 tested with two-step reveal ✅
- Working on Rarible testnet
