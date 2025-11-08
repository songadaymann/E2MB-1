// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../core/SongAlgorithm.sol";
import "../render/post/AudioRenderer.sol";
import "../render/post/MusicRenderer.sol";

interface IMusicRendererContract {
    function render(MusicRenderer.BeatData calldata data) external view returns (string memory);
}

/**
 * @title MillenniumSongTestnet
 * @notice Minimal version for testnet deployment (under 24KB)
 * @dev Uses external MusicRendererContract for staff SVG to save size
 */
contract MillenniumSongTestnet is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 public constant START_YEAR = 2026;
    uint256 public totalMinted;
    
    address public musicRenderer;  // External renderer contract
    
    mapping(uint256 => uint256) public points;
    mapping(uint256 => uint256) public basePermutation;
    mapping(uint256 => bool) public revealed;
    mapping(uint256 => SongAlgorithm.Event) public revealedLeadNote;
    mapping(uint256 => SongAlgorithm.Event) public revealedBassNote;
    mapping(uint256 => uint256) public revealBlockTimestamp;
    mapping(uint256 => bytes32) public sevenWords;
    
    bytes32 public previousNotesHash;
    bytes32 public globalState;
    
    event NoteRevealed(uint256 indexed tokenId, uint256 beat, int16 leadPitch, int16 bassPitch, uint256 timestamp);
    
    constructor() ERC721("Millennium Song Testnet", "MSONGT") Ownable(msg.sender) {}
    
    function setMusicRenderer(address _renderer) external onlyOwner {
        musicRenderer = _renderer;
    }
    
    function mint(address to, uint32 seed) external onlyOwner returns (uint256 tokenId) {
        tokenId = ++totalMinted;
        _safeMint(to, tokenId);
        basePermutation[tokenId] = tokenId;
    }
    
    function setSevenWords(uint256 tokenId, bytes32 words) external {
        require(_ownerOf(tokenId) == msg.sender || msg.sender == owner(), "Not authorized");
        require(!revealed[tokenId], "Already revealed");
        sevenWords[tokenId] = words;
    }
    
    function forceReveal(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        
        revealed[tokenId] = true;
        revealBlockTimestamp[tokenId] = block.timestamp;
        
        uint32 seed = uint32(uint256(keccak256(abi.encodePacked(
            previousNotesHash,
            block.timestamp,
            tokenId,
            sevenWords[tokenId],
            globalState
        ))));
        
        (SongAlgorithm.Event memory lead, SongAlgorithm.Event memory bass) = 
            SongAlgorithm.generateBeat(uint32(tokenId), seed);
        
        revealedLeadNote[tokenId] = lead;
        revealedBassNote[tokenId] = bass;
        
        previousNotesHash = keccak256(abi.encodePacked(
            previousNotesHash,
            lead.pitch, lead.duration,
            bass.pitch, bass.duration
        ));
        
        emit NoteRevealed(tokenId, tokenId, lead.pitch, bass.pitch, block.timestamp);
    }
    
    function getCurrentRank(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = 0;
        for (uint256 i = 1; i <= totalMinted; i++) {
            if (i == tokenId) continue;
            if (points[i] > points[tokenId] || 
                (points[i] == points[tokenId] && basePermutation[i] < basePermutation[tokenId])) {
                rank++;
            }
        }
        return rank;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        
        string memory svg;
        string memory animationUrl;
        
        if (revealed[tokenId]) {
            // Simple SVG with text info
            svg = string(abi.encodePacked(
                'data:image/svg+xml;base64,',
                Base64.encode(bytes(string(abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">',
                    '<rect width="600" height="600" fill="#fff"/>',
                    '<text x="300" y="100" text-anchor="middle" font-family="monospace" font-size="32" fill="#000">',
                    'Token #', tokenId.toString(), '</text>',
                    '<text x="300" y="200" text-anchor="middle" font-family="monospace" font-size="24" fill="#000">',
                    'Year ', revealYear.toString(), '</text>',
                    '<text x="300" y="300" text-anchor="middle" font-family="monospace" font-size="20" fill="#000">',
                    'Lead: MIDI ', _int16ToString(revealedLeadNote[tokenId].pitch), '</text>',
                    '<text x="300" y="350" text-anchor="middle" font-family="monospace" font-size="20" fill="#000">',
                    'Bass: MIDI ', _int16ToString(revealedBassNote[tokenId].pitch), '</text>',
                    '<text x="300" y="450" text-anchor="middle" font-family="monospace" font-size="16" fill="#666">',
                    'Click animation_url to hear</text>',
                    '<text x="300" y="500" text-anchor="middle" font-family="monospace" font-size="16" fill="#666">',
                    'continuous organ tones</text>',
                    '</svg>'
                ))))
            ));
            
            animationUrl = AudioRenderer.generateAudioHTML(
                revealedLeadNote[tokenId].pitch,
                revealedBassNote[tokenId].pitch,
                revealBlockTimestamp[tokenId],
                tokenId,
                revealYear
            );
        } else {
            svg = string(abi.encodePacked(
                'data:image/svg+xml;base64,',
                Base64.encode(bytes(string(abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">',
                    '<rect width="600" height="600" fill="#000"/>',
                    '<text x="300" y="300" text-anchor="middle" font-family="monospace" font-size="32" fill="#0f0">',
                    'UNREVEALED</text>',
                    '<text x="300" y="350" text-anchor="middle" font-family="monospace" font-size="20" fill="#0f0">',
                    'Year ', revealYear.toString(), '</text>',
                    '</svg>'
                ))))
            ));
            animationUrl = "";
        }
        
        bytes memory json = abi.encodePacked(
            '{"name":"Millennium Song #', tokenId.toString(), ' - Year ', revealYear.toString(), '",',
            '"description":"On-chain generative music. Continuous organ tones ring since reveal.",',
            '"image":"', svg, '",',
            '"animation_url":"', animationUrl, '",',
            '"attributes":[',
            '{"trait_type":"Year","value":', revealYear.toString(), '},',
            '{"trait_type":"Status","value":"', revealed[tokenId] ? 'Revealed' : 'Unrevealed', '"},',
            '{"trait_type":"Rank","value":', rank.toString(), '}',
            ']}'
        );
        
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }
    
    function _int16ToString(int16 value) private pure returns (string memory) {
        if (value == -1) return "REST";
        if (value >= 0) return Strings.toString(uint256(int256(value)));
        return string(abi.encodePacked("-", Strings.toString(uint256(int256(-value)))));
    }
}
