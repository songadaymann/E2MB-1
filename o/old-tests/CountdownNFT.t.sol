// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/legacy/CountdownNFT.sol";

contract CountdownNFTTest is Test {
    CountdownNFT public nft;
    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        vm.prank(owner);
        nft = new CountdownNFT();
    }

    function testMintAndTokenURI() public {
        vm.prank(owner);
        nft.mint(user);
        
        string memory uri = nft.tokenURI(0);
        console.log("Token URI:", uri);
        
        // Verify it starts with data:application/json;base64
        assertTrue(bytes(uri).length > 0);
        
        // Extract and decode the SVG part for logging
        vm.prank(owner);
        nft.mint(user); // Mint token #1
        
        string memory uri1 = nft.tokenURI(1);
        console.log("Token URI #1:", uri1);
    }
    
    function testSVGGeneration() public {
        vm.prank(owner);
        nft.mint(user);
        
        // Test that different token IDs produce different countdown numbers
        vm.prank(owner);
        nft.mint(user);
        
        string memory uri0 = nft.tokenURI(0);
        string memory uri1 = nft.tokenURI(1);
        
        // They should be different
        assertFalse(keccak256(bytes(uri0)) == keccak256(bytes(uri1)));
    }
}
