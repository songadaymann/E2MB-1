#!/bin/bash

# Source env
source .env

# Verify PointsAggregator
~/.foundry/bin/forge verify-contract 0x471a202564FD5297781B9c362a2eC2618f662624 src/points/PointsAggregator.sol:PointsAggregator --verifier etherscan --verifier-url https://api-sepolia.etherscan.io/api --etherscan-api-key $ETHERSCAN_API_KEY --constructor-args 0x000000000000000000000000E747263e5e7db4Dd17cb4502bC037B0B18d7aBd0

# Verify L1BurnCollector
~/.foundry/bin/forge verify-contract 0x9962CffFEbEb0e75ea99B00d7F73979B4D9EA58B src/points/L1BurnCollector.sol:L1BurnCollector --verifier etherscan --verifier-url https://api-sepolia.etherscan.io/api --etherscan-api-key $ETHERSCAN_API_KEY --constructor-args 0x000000000000000000000000471a202564FD5297781B9c362a2eC2618f662624
