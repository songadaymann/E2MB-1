// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";

interface IE2MBView {
    function basePermutation(uint256 tokenId) external view returns (uint256);
    function getCurrentRank(uint256 tokenId) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract InspectPermutation is Script {
    function run() external {
        address msong = vm.envAddress("MSONG_ADDRESS");
        IE2MBView nft = IE2MBView(msong);

        uint256 total = nft.totalSupply();
        console.log("Total minted:", total);

        for (uint256 tokenId = 1; tokenId <= total; tokenId++) {
            uint256 baseIdx = nft.basePermutation(tokenId);
            uint256 rank = nft.getCurrentRank(tokenId);
            console.log(tokenId, baseIdx, rank);
        }
    }
}
