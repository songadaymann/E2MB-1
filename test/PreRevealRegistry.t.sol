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
import "../src/render/pre/PreRevealRegistry.sol";
contract PreRevealRegistryTest is Test {

    EveryTwoMillionBlocks private nft;
    PreRevealRegistry private registry;
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
        registry = new PreRevealRegistry(address(this));
        registry.setController(address(nft));
        nft.setPreRevealRegistry(address(registry));
        nft.setRenderers(address(songAlgorithm), address(musicRenderer), address(audioRenderer));

        defaultSvg = new MockCountdownRenderer("default-");
        defaultHtml = new MockCountdownHtmlRenderer("default-html-");
        uint256 defaultId = registry.addRenderer(address(defaultSvg), address(defaultHtml), true);
        registry.setDefaultRenderer(defaultId);
    }

    function testTokenUriUsesDefaultRendererWhenUnset() public {
        uint256 tokenId = nft.mint(user, 42);
        (uint256 rendererId, bool isCustom) = registry.getTokenRenderer(tokenId);
        assertEq(rendererId, 0);
        assertFalse(isCustom);
        string memory tokenUri = nft.tokenURI(tokenId);
        assertTrue(bytes(tokenUri).length > 0);
    }

    function testTokenUriUsesCustomRendererWhenSelected() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        MockCountdownHtmlRenderer customHtml = new MockCountdownHtmlRenderer("life-html-");
        uint256 rendererId = registry.addRenderer(address(customSvg), address(customHtml), true);

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
        uint256 rendererId = registry.addRenderer(address(customSvg), address(customHtml), true);

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
        registry.freeze();
        MockCountdownRenderer customSvg = new MockCountdownRenderer("frozen-");
        vm.expectRevert("Registry frozen");
        registry.addRenderer(address(customSvg), address(0), true);
    }

    function testSetTokenRequiresAuthorization() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        uint256 rendererId = registry.addRenderer(address(customSvg), address(0), true);

        uint256 tokenId = nft.mint(user, 88);

        vm.expectRevert(bytes("Not authorized"));
        nft.setTokenPreRevealRenderer(tokenId, rendererId);
    }

    function testSetDefaultRequiresActiveRenderer() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        uint256 rendererId = registry.addRenderer(address(customSvg), address(0), false);

        vm.expectRevert("Renderer inactive");
        registry.setDefaultRenderer(rendererId);
    }

    function testNonCuratorCannotAddRenderer() public {
        address rando = address(0xABCD);
        MockCountdownRenderer customSvg = new MockCountdownRenderer("blocked-");
        vm.prank(rando);
        vm.expectRevert("Not curator");
        registry.addRenderer(address(customSvg), address(0), true);
    }

    function testCuratorCanAddRenderer() public {
        address curator = address(0xCAFE);
        registry.setCurator(curator, true);
        MockCountdownRenderer customSvg = new MockCountdownRenderer("cur-");
        vm.prank(curator);
        uint256 rendererId = registry.addRenderer(address(customSvg), address(0), true);
        assertEq(rendererId, 1);
    }

    function testSetCuratorRequiresValidAddress() public {
        vm.expectRevert("Invalid curator");
        registry.setCurator(address(0), true);
    }

    function testAdminCanRemoveCurator() public {
        address curator = address(0x1234);
        registry.setCurator(curator, true);
        assertTrue(registry.isCurator(curator));
        registry.setCurator(curator, false);
        assertFalse(registry.isCurator(curator));
    }

    function testControllerCannotBeChangedOnceSet() public {
        assertTrue(registry.controllerLocked());
        vm.expectRevert("Controller locked");
        registry.setController(address(0x1234));
    }

    function testControllerRequiresNonZeroAddress() public {
        PreRevealRegistry newRegistry = new PreRevealRegistry(address(this));
        vm.expectRevert("Controller required");
        newRegistry.setController(address(0));
    }

    function testRendererRequiresSevenWords() public {
        MockCountdownRenderer customSvg = new MockCountdownRenderer("life-");
        uint256 rendererId = registry.addRenderer(address(customSvg), address(0), true);
        registry.setRendererRequiresSevenWords(rendererId, true);

        uint256 tokenId = nft.mint(user, 90);

        vm.prank(user);
        vm.expectRevert(bytes("Seven words not set"));
        nft.setTokenPreRevealRenderer(tokenId, rendererId);

        vm.prank(user);
        nft.setSevenWords(tokenId, "eternal sound resonance time memory future song");

        vm.prank(user);
        nft.setTokenPreRevealRenderer(tokenId, rendererId);
    }
}
