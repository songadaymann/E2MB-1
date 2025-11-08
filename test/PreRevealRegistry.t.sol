// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/EveryTwoMillionBlocks.sol";
import "../src/render/post/SvgMusicGlyphs.sol";
import "../src/render/post/StaffUtils.sol";
import "../src/render/post/MidiToStaff.sol";
import "../src/render/post/NotePositioning.sol";
import "../src/contracts/MusicRendererOrchestrator.sol";
import "../src/render/post/AudioRenderer.sol";
import "../src/core/SongAlgorithm.sol";
import "../test/mocks/MockCountdownRenderers.sol";
contract PreRevealRegistryTest is Test {

    EveryTwoMillionBlocks private nft;
    MusicRendererOrchestrator private musicRenderer;
    AudioRenderer private audioRenderer;
    SongAlgorithm private songAlgorithm;

    MockCountdownRenderer private defaultSvg;
    MockCountdownHtmlRenderer private defaultHtml;

    address private owner = address(this);
    address private user = address(0xBEEF);

    function setUp() public {
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        StaffUtils staff = new StaffUtils();
        MidiToStaff midi = new MidiToStaff();
        NotePositioning positioning = new NotePositioning();

        musicRenderer = new MusicRendererOrchestrator(
            address(staff),
            address(glyphs),
            address(midi),
            address(positioning)
        );

        audioRenderer = new AudioRenderer();
        songAlgorithm = new SongAlgorithm();

        nft = new EveryTwoMillionBlocks();
        nft.setRenderers(address(songAlgorithm), address(musicRenderer), address(audioRenderer));

        defaultSvg = new MockCountdownRenderer("default-");
        defaultHtml = new MockCountdownHtmlRenderer("default-html-");
        nft.setCountdownRenderer(address(defaultSvg));
        nft.setCountdownHtmlRenderer(address(defaultHtml));
        nft.setDefaultPreRevealRenderer(0);
    }

    function testTokenUriUsesDefaultRendererWhenUnset() public {
        uint256 tokenId = nft.mint(user, 42);
        (uint256 rendererId, bool isCustom) = nft.getTokenPreRevealRenderer(tokenId);
        assertEq(rendererId, 0);
        assertFalse(isCustom);
        string memory tokenUri = nft.tokenURI(tokenId);
        assertTrue(bytes(tokenUri).length > 0);
    }

    function testTokenUriUsesCustomRendererWhenSelected() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        MockCountdownHtmlRenderer customHtml = new MockCountdownHtmlRenderer("life-html-");
        uint256 rendererId = nft.addPreRevealRenderer(address(customSvg), address(customHtml), true);

        uint256 tokenId = nft.mint(user, 55);

        string memory defaultUri = nft.tokenURI(tokenId);

        vm.prank(user);
        nft.setTokenPreRevealRenderer(tokenId, rendererId);

        string memory tokenUri = nft.tokenURI(tokenId);
        assertNotEq(keccak256(bytes(tokenUri)), keccak256(bytes(defaultUri)));
    }

    function testCustomRendererFallbacksWhenReverts() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        MockCountdownHtmlRenderer customHtml = new MockCountdownHtmlRenderer("life-html-");
        uint256 rendererId = nft.addPreRevealRenderer(address(customSvg), address(customHtml), true);

        uint256 tokenId = nft.mint(user, 77);
        string memory defaultUri = nft.tokenURI(tokenId);

        vm.prank(user);
        nft.setTokenPreRevealRenderer(tokenId, rendererId);

        string memory customUri = nft.tokenURI(tokenId);
        assertNotEq(keccak256(bytes(customUri)), keccak256(bytes(defaultUri)));

        customSvg.setShouldRevert(true);
        customHtml.setShouldRevert(true);

        string memory tokenUri = nft.tokenURI(tokenId);
        assertEq(keccak256(bytes(tokenUri)), keccak256(bytes(defaultUri)));
    }

    function testFreezeRegistryPreventsUpdates() public {
        nft.freezePreRevealRegistry();
        MockCountdownRenderer customSvg = new MockCountdownRenderer("frozen-");
        vm.expectRevert("Pre-reveal registry frozen");
        nft.addPreRevealRenderer(address(customSvg), address(0), true);
    }

    function testSetTokenRequiresAuthorization() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        uint256 rendererId = nft.addPreRevealRenderer(address(customSvg), address(0), true);

        uint256 tokenId = nft.mint(user, 88);

        vm.expectRevert(bytes("Not authorized"));
        nft.setTokenPreRevealRenderer(tokenId, rendererId);
    }

    function testSetDefaultRequiresActiveRenderer() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        uint256 rendererId = nft.addPreRevealRenderer(address(customSvg), address(0), false);

        vm.expectRevert("Renderer inactive");
        nft.setDefaultPreRevealRenderer(rendererId);
    }
}
