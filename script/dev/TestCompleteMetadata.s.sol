// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../../src/core/SongAlgorithm.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/render/post/AudioRenderer.sol";

/// @title TestCompleteMetadata
/// @notice Generate complete tokenURI metadata JSON for a revealed token
/// @dev Shows the full structure with all attributes, image SVG, and audio HTML
contract TestCompleteMetadata is Script {
    using Strings for uint256;
    
    function run() external {
        console.log("=== GENERATING COMPLETE TOKEN METADATA ===");
        console.log("");
        
        // Deploy all contracts
        console.log("Deploying contracts...");
        SongAlgorithm algo = new SongAlgorithm();
        StaffUtils staffUtils = new StaffUtils();
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        MidiToStaff midiToStaff = new MidiToStaff();
        NotePositioning positioning = new NotePositioning();
        AudioRenderer audio = new AudioRenderer();
        
        MusicRendererOrchestrator musicRenderer = new MusicRendererOrchestrator(
            address(staffUtils),
            address(glyphs),
            address(midiToStaff),
            address(positioning)
        );
        
        console.log("SongAlgorithm:", address(algo));
        console.log("MusicRenderer:", address(musicRenderer));
        console.log("AudioRenderer:", address(audio));
        console.log("");
        
        // Generate metadata for Token #1, revealed in year 2026
        uint256 tokenId = 1;
        uint32 beat = 0;
        uint256 year = 2026;
        uint256 rank = 0;
        uint256 points = 0;
        
        // Compute seed using 5-source method
        uint32 finalSeed = _computeFinalSeed(tokenId);
        console.log("Token #%d - Beat %d - Year %d", tokenId, beat, year);
        console.log("Final seed: %d", finalSeed);
        console.log("");
        
        // Generate music
        (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
            algo.generateBeat(beat, finalSeed);
        
        console.log("Lead: MIDI", _int16ToString(lead.pitch), "duration", lead.duration);
        console.log("Bass: MIDI", uint256(uint16(bass.pitch)), "duration", bass.duration);
        console.log("");
        
        // Generate SVG image
        string memory imageSvg = musicRenderer.render(IMusicRenderer.BeatData({
            tokenId: tokenId,
            beat: beat,
            year: year,
            leadPitch: lead.pitch,
            leadDuration: lead.duration,
            bassPitch: bass.pitch,
            bassDuration: bass.duration
        }));
        
        string memory imageDataUri = string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(imageSvg))
        ));
        
        console.log("Image SVG generated (%d bytes)", bytes(imageSvg).length);
        
        // Generate audio HTML
        uint256 revealTimestamp = 1735689600; // Jan 1, 2026 00:00:00 UTC
        string memory audioHtml = audio.generateAudioHTML(
            lead.pitch,
            bass.pitch,
            revealTimestamp,
            imageSvg  // Pass the raw SVG content
        );
        
        console.log("Audio HTML generated (%d bytes)", bytes(audioHtml).length);
        console.log("");
        
        // Build complete metadata JSON
        string memory metadata = _buildMetadata(
            tokenId,
            year,
            rank,
            points,
            imageDataUri,
            audioHtml,
            lead,
            bass,
            revealTimestamp
        );
        
        // Encode as data URI (as tokenURI would return)
        string memory tokenUri = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(metadata))
        ));
        
        // Save outputs
        _saveOutputs(metadata, imageSvg, audioHtml, tokenUri);
        
        console.log("=== COMPLETE ===");
        console.log("Files saved to OUTPUTS/complete-metadata/");
        console.log("");
        console.log("Files generated:");
        console.log("  1. metadata.json - Complete JSON metadata (decoded)");
        console.log("  2. metadata-data-uri.txt - Full tokenURI() response");
        console.log("  3. image.svg - SVG image (decoded from data URI)");
        console.log("  4. animation.html - Audio player HTML");
        console.log("");
        console.log("To view in browser:");
        console.log("  open OUTPUTS/complete-metadata/image.svg");
        console.log("  open OUTPUTS/complete-metadata/animation.html");
    }
    
    function _buildMetadata(
        uint256 tokenId,
        uint256 year,
        uint256 rank,
        uint256 points,
        string memory imageDataUri,
        string memory animationUrl,
        ISongAlgorithm.Event memory lead,
        ISongAlgorithm.Event memory bass,
        uint256 revealTimestamp
    ) internal pure returns (string memory) {
        // Build JSON manually for clarity
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "name": "Millennium Song #', tokenId.toString(), ' - Year ', year.toString(), '",\n',
            '  "description": "Millennium Song token #', tokenId.toString(),
            ' - Year ', year.toString(), '. Continuous organ tones ring since reveal.",\n',
            '  "image": "', imageDataUri, '",\n',
            '  "animation_url": "', animationUrl, '",\n',
            '  "external_url": "https://millenniumsong.art/token/', tokenId.toString(), '",\n'
        ));
        
        // Attributes array
        json = string(abi.encodePacked(
            json,
            '  "attributes": [\n',
            '    {"trait_type": "Year", "value": ', year.toString(), '},\n',
            '    {"trait_type": "Queue Rank", "value": ', rank.toString(), '},\n',
            '    {"trait_type": "Points", "value": ', points.toString(), '},\n',
            '    {"trait_type": "Reveal Timestamp", "value": ', revealTimestamp.toString(), '},\n',
            '    {"trait_type": "Reveal Date", "display_type": "date", "value": ', revealTimestamp.toString(), '},\n',
            '    {"trait_type": "Lead Pitch (MIDI)", "value": ', _int16ToString(lead.pitch), '},\n'
        ));
        
        json = string(abi.encodePacked(
            json,
            '    {"trait_type": "Lead Note", "value": "', _midiToNoteName(lead.pitch), '"},\n',
            '    {"trait_type": "Lead Duration", "value": ', uint256(lead.duration).toString(), '},\n',
            '    {"trait_type": "Lead Duration Type", "value": "', _durationToType(lead.duration), '"},\n',
            '    {"trait_type": "Bass Pitch (MIDI)", "value": ', _int16ToString(bass.pitch), '},\n',
            '    {"trait_type": "Bass Note", "value": "', _midiToNoteName(bass.pitch), '"},\n',
            '    {"trait_type": "Bass Duration", "value": ', uint256(bass.duration).toString(), '},\n',
            '    {"trait_type": "Bass Duration Type", "value": "', _durationToType(bass.duration), '"}\n',
            '  ]\n',
            '}\n'
        ));
        
        return json;
    }
    
    function _computeFinalSeed(uint256 tokenId) internal view returns (uint32) {
        // Simulate the 5-source seed computation
        uint32 tokenSeed = uint32(uint256(keccak256(abi.encodePacked(block.timestamp, tokenId))));
        bytes32 sevenWords = keccak256("eternal harmony resonance time melody transcend infinity");
        bytes32 previousNotes = bytes32(0); // First token
        bytes32 globalState = keccak256("millennium-song-mainnet");
        
        return uint32(uint256(keccak256(abi.encodePacked(
            tokenSeed,
            sevenWords,
            previousNotes,
            globalState,
            tokenId
        ))));
    }
    
    function _saveOutputs(
        string memory metadata,
        string memory imageSvg,
        string memory audioHtml,
        string memory tokenUri
    ) internal {
        // Create directory
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "OUTPUTS/complete-metadata";
        vm.ffi(mkdirCmd);
        
        // Save decoded JSON
        vm.writeFile("OUTPUTS/complete-metadata/metadata.json", metadata);
        
        // Save full tokenURI (base64 encoded)
        vm.writeFile("OUTPUTS/complete-metadata/metadata-data-uri.txt", tokenUri);
        
        // Save decoded image SVG
        vm.writeFile("OUTPUTS/complete-metadata/image.svg", imageSvg);
        
        // Save decoded audio HTML
        vm.writeFile("OUTPUTS/complete-metadata/animation.html", audioHtml);
    }
    
    function _midiToNoteName(int16 midi) internal pure returns (string memory) {
        if (midi < 0) return "REST";
        
        string[12] memory noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
        uint16 noteClass = uint16(midi) % 12;
        uint16 octave = uint16(midi) / 12;
        
        return string(abi.encodePacked(noteNames[noteClass], uint256(octave).toString()));
    }
    
    function _durationToType(uint16 duration) internal pure returns (string memory) {
        if (duration >= 1920) return "Whole Note";
        if (duration >= 960) return "Half Note";
        if (duration >= 720) return "Dotted Quarter";
        if (duration >= 480) return "Quarter Note";
        if (duration >= 240) return "Eighth Note";
        return "Sixteenth Note";
    }
    
    function _int16ToString(int16 value) internal pure returns (string memory) {
        if (value >= 0) {
            return uint256(uint16(value)).toString();
        } else {
            return string(abi.encodePacked("-1 (REST)"));
        }
    }
}
