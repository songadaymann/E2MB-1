# Deployed Addresses (Sepolia)

**Latest Deployment:** Nov 15, 2025 17:06 UTC — Fresh E2MB + registry + Life lens wiring

## Points System Contracts ✅
- **PointsManager:** `0x7538Cf5d33283FfFE105A446ED85e1FA26Aa5640`
- **PointsAggregator:** `0xC2ed19efE6400B740E588f1019cdcb87C57694dC`
- **L1BurnCollector:** `0xAf46d12550fb5D009FB0873453c64f3ffd7B00F9`
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
- **DummyERC1155 (10k pts per copy):** `0x7Ef7dF0F64A2591fd5bE9c1E88728e59CB5D362B`
- **DummyERC20 (1 pt per token, decimals=18):** `0xD2DcB326F003DC8db194C74Db2749F8C653Df6aC`

## Main Contract ✅
- **EveryTwoMillionBlocks:** `0x18a09608810f87f76061f4E075Edc49115194B78`
  - Name: "Every Two Million Blocks"
  - Symbol: "E2MB"
  - Fresh deploy (Nov 15 2025) wired to new points stack + VRF v2.5 + pre-reveal registry
  - **Rarible:** https://testnet.rarible.com/token/sepolia/0x18a09608810f87f76061f4e075edc49115194b78:1

- **SvgMusicGlyphs:** `0x5976bee500cE9FbF5C73f5dBAB1d1737509566B7`
- **StaffUtils:** `0x764D8ECE520c9B0a94ED901650935f49F673052B`
- **MidiToStaff:** `0x0859654EEbcAF7f32c9Ec68efA0bb832a06c67F0`
- **NotePositioning:** `0x089a03b1282D93ff7Ed59582c51772A4397e0531`
- **MusicRenderer:** `0xAcAeef7C655665188E26d4F6570e0fc65c116830`
- **AudioRenderer:** `0xBD0Af886ADA865573F95656E64BA38F4Ee94859b`
- **SongAlgorithm:** `0xec0ECE1C903c4fE44C17178C8739e57A362CF2da`
- **PreRevealRegistry:** `0x10C046CAC7Acc33D3fFEfEbbC3Ff630CDcC72910`
- **LifeLensInit:** `0x396eFaF29792a829D6737b734328c7C20df1Da46`
- **LifeLens SVG:** `0xC99880AA63B71DF17f1FEF1e00a37546D7ce993E`
- **LifeLens HTML:** `0x83073cD0874b99F2962a9D0aA31eb84E988BA258`

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
