// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

interface IE2MBPermutation {
    function ingestPermutationChunk(uint256[] calldata tokenIds, uint256[] calldata permutationIndices) external;
    function totalSupply() external view returns (uint256);
}

contract IngestPermutation is Script {
    using stdJson for string;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address msong = vm.envAddress("MSONG_ADDRESS");

        string memory jsonPath = vm.envString("PERMUTATION_JSON");
        uint256 offset = vm.envOr("PERMUTATION_OFFSET", uint256(0));
        uint256 chunkSize = vm.envOr("PERMUTATION_CHUNK", uint256(100));

        string memory json = vm.readFile(jsonPath);
        uint256 total = json.readUint(".total");
        uint256[] memory permutation = json.readUintArray(".permutation");
        require(permutation.length == total, "Permutation length mismatch");
        require(offset < total, "Offset out of range");
        require(chunkSize > 0, "Chunk size zero");

        uint256 endExclusive = offset + chunkSize;
        if (endExclusive > total) {
            endExclusive = total;
        }
        uint256 count = endExclusive - offset;
        require(count > 0, "Nothing to ingest");

        uint256[] memory tokenIds = new uint256[](count);
        uint256[] memory permIndices = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = offset + i + 1; // tokenIds are 1-indexed
            permIndices[i] = permutation[offset + i];
        }

        console.log("Ingesting permutation chunk");
        console.log("  address:", msong);
        console.log("  offset:", offset);
        console.log("  size:", count);

        uint256 minted = IE2MBPermutation(msong).totalSupply();
        console.log("  total supply:", minted);

        vm.startBroadcast(deployerKey);
        IE2MBPermutation(msong).ingestPermutationChunk(tokenIds, permIndices);
        vm.stopBroadcast();
    }
}
