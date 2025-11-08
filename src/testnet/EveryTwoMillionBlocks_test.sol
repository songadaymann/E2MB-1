// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces for external contracts
import "../interfaces/ISongAlgorithm.sol";
import "../interfaces/IMusicRenderer.sol";
import "../interfaces/IAudioRenderer.sol";

// Countdown renderer (still a library for now)
import "../render/pre/CountdownRenderer.sol";
import "../render/IRenderTypes.sol";

/**
 * @title EveryTwoMillionBlocks_test
 * @notice TESTNET VERSION - Carbon copy of EveryTwoMillionBlocks with virtual functions
 * @dev This is identical to the production contract except:
 *      - Contract name changed to EveryTwoMillionBlocks_test
 *      - getCurrentRank() is virtual (allows fast-reveal testing)
 *      - _jan1Timestamp() is virtual and internal (allows time override)
 *      DO NOT DEPLOY TO MAINNET - Use EveryTwoMillionBlocks.sol for production
 */
contract EveryTwoMillionBlocks_test is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant START_YEAR = 2026;

    uint256 public totalMinted;
    mapping(uint256 => uint32) public tokenSeed;
    
    // --- EXTERNAL CONTRACT ADDRESSES ---
    ISongAlgorithm public songAlgorithm;
    IMusicRenderer public musicRenderer;
    IAudioRenderer public audioRenderer;
    
    bool public renderersFinalized;
    
    // --- DYNAMIC RANKING ---
    mapping(uint256 => uint256) public points;
    mapping(uint256 => uint256) public basePermutation;
    
    // --- CROSS-CHAIN MESSENGERS (L2 → L1) ---
    address public baseMessenger = 0x4200000000000000000000000000000000000007;
    address public optimismMessenger = 0x4200000000000000000000000000000000000007;
    address public arbitrumInbox;
    address public zoraMessenger = 0x4200000000000000000000000000000000000007;
    
    // L1 Burn handling
    mapping(address => uint256) public eligibleL1Assets;
    uint256[12] public monthWeights;
    
    // --- REVEAL SYSTEM ---
    mapping(uint256 => bool) public revealed;
    mapping(uint256 => ISongAlgorithm.Event) public revealedLeadNote;
    mapping(uint256 => ISongAlgorithm.Event) public revealedBassNote;
    mapping(uint256 => uint256) public revealBlockTimestamp;
    
    // --- SEED COMPONENTS ---
    mapping(uint256 => bytes32) public sevenWords;
    mapping(uint256 => string) public sevenWordsText;
    bytes32 public previousNotesHash;
    bytes32 public globalState;
    
    // --- TWO-STEP REVEAL STATE ---
    mapping(uint256 => bool) public revealPending;
    mapping(uint256 => uint32) public pendingBeat;
    mapping(uint256 => bytes32) public pendingWords;
    
    event NoteRevealed(
        uint256 indexed tokenId, 
        uint256 beat, 
        int16 leadPitch, 
        int16 bassPitch,
        uint256 timestamp
    );
    
    event PointsApplied(
        uint256 indexed tokenId,
        uint256 pointsDelta,
        uint256 newTotal,
        string source
    );
    
    event CheckpointReceived(
        string indexed chain,
        uint256 addressCount,
        uint256 totalPoints
    );
    
    event RenderersUpdated(address music, address audio, address countdown);
    event RenderersFinalized();
    event RevealPrepared(uint256 indexed tokenId, uint32 beat, bytes32 words);
    event RevealCancelled(uint256 indexed tokenId);

    constructor() ERC721("Every Two Million Blocks TEST", "E2MB-TEST") Ownable(msg.sender) {
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    }
    
    // --- RENDERER MANAGEMENT ---
    modifier renderersNotFinalized() {
        require(!renderersFinalized, "Renderers finalized");
        _;
    }
    
    /// @notice Set external contract addresses (only before finalization)
    function setRenderers(
        address _songAlgorithm,
        address _music,
        address _audio
    ) external onlyOwner renderersNotFinalized {
        songAlgorithm = ISongAlgorithm(_songAlgorithm);
        musicRenderer = IMusicRenderer(_music);
        audioRenderer = IAudioRenderer(_audio);
        emit RenderersUpdated(_music, _audio, _songAlgorithm);
    }
    
    /// @notice Finalize renderer addresses (one-way, cannot be changed after)
    function finalizeRenderers() external onlyOwner {
        renderersFinalized = true;
        emit RenderersFinalized();
    }

    // --- MINTING ---
    function mint(address to, uint32 seed) external onlyOwner returns (uint256 tokenId) {
        require(totalMinted < MAX_SUPPLY, "sold out");
        tokenId = ++totalMinted;
        _safeMint(to, tokenId);
        tokenSeed[tokenId] = (seed == 0)
            ? uint32(uint256(keccak256(abi.encodePacked(block.timestamp, to, tokenId))))
            : seed;
        
        basePermutation[tokenId] = tokenId;
    }
    
    /// @notice Set the seven words for a token (owner can do this before reveal)
    function setSevenWords(uint256 tokenId, string calldata wordsText) external {
        require(_ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!revealed[tokenId], "Already revealed");
        sevenWords[tokenId] = keccak256(bytes(wordsText));
        sevenWordsText[tokenId] = wordsText;
    }
    
    /// @notice Initialize or update global state (owner only, for testing)
    function setGlobalState(bytes32 newState) external onlyOwner {
        globalState = newState;
    }

    // --- REVEAL FUNCTIONS ---
    function revealNote(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        uint256 revealTime = _jan1Timestamp(revealYear);
        
        require(block.timestamp >= revealTime, "Not reveal time yet");
        
        _performReveal(tokenId, rank);
    }
    
    /// @notice TEST ONLY: Force reveal a token (bypasses time check)
    function forceReveal(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        
        uint256 rank = getCurrentRank(tokenId);
        _performReveal(tokenId, rank);
    }
    
    // --- TWO-STEP REVEAL (Gas-Optimized) ---
    
    /// @notice Step 1: Prepare reveal by computing rank and locking inputs
    /// @dev Separates expensive rank computation from music generation
    function prepareReveal(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        require(!revealPending[tokenId], "Reveal already pending");
        
        // Compute rank (expensive O(n) operation)
        uint256 rank = getCurrentRank(tokenId);
        
        // Snapshot state to prevent manipulation
        pendingBeat[tokenId] = uint32(rank);
        pendingWords[tokenId] = sevenWords[tokenId];
        revealPending[tokenId] = true;
        
        emit RevealPrepared(tokenId, uint32(rank), sevenWords[tokenId]);
    }
    
    /// @notice Step 2: Finalize reveal by generating and storing music
    /// @dev Uses snapshotted inputs from prepareReveal
    function finalizeReveal(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(revealPending[tokenId], "No pending reveal");
        require(!revealed[tokenId], "Already revealed");
        
        // Validate seven words haven't changed (anti-manipulation)
        require(sevenWords[tokenId] == pendingWords[tokenId], "Seven words changed");
        
        // Mark as revealed
        revealed[tokenId] = true;
        revealBlockTimestamp[tokenId] = block.timestamp;
        
        // Compute seed using snapshotted words and current previousNotesHash
        uint32 seed = _computeRevealSeed(tokenId);
        
        // Generate music (external contract call)
        (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
            songAlgorithm.generateBeat(pendingBeat[tokenId], seed);
        
        // Store revealed notes
        revealedLeadNote[tokenId] = lead;
        revealedBassNote[tokenId] = bass;
        
        // Update cumulative hash
        previousNotesHash = keccak256(abi.encodePacked(
            previousNotesHash,
            lead.pitch,
            lead.duration,
            bass.pitch,
            bass.duration
        ));
        
        // Clear pending state
        revealPending[tokenId] = false;
        delete pendingBeat[tokenId];
        delete pendingWords[tokenId];
        
        emit NoteRevealed(tokenId, pendingBeat[tokenId], lead.pitch, bass.pitch, block.timestamp);
    }
    
    /// @notice Cancel a pending reveal
    /// @dev Allows owner or token owner to reset pending state
    function cancelReveal(uint256 tokenId) external {
        require(msg.sender == owner() || msg.sender == _ownerOf(tokenId), "Not authorized");
        require(revealPending[tokenId], "No pending reveal");
        
        revealPending[tokenId] = false;
        delete pendingBeat[tokenId];
        delete pendingWords[tokenId];
        
        emit RevealCancelled(tokenId);
    }
    
    function _performReveal(uint256 tokenId, uint256 rank) private {
        revealed[tokenId] = true;
        revealBlockTimestamp[tokenId] = block.timestamp;
        
        uint32 beat = uint32(rank);
        uint32 seed = _computeRevealSeed(tokenId);
        
        (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
            songAlgorithm.generateBeat(beat, seed);
        
        revealedLeadNote[tokenId] = lead;
        revealedBassNote[tokenId] = bass;
        
        previousNotesHash = keccak256(abi.encodePacked(
            previousNotesHash,
            lead.pitch,
            lead.duration,
            bass.pitch,
            bass.duration
        ));
        
        emit NoteRevealed(tokenId, beat, lead.pitch, bass.pitch, block.timestamp);
    }
    
    function _computeRevealSeed(uint256 tokenId) private view returns (uint32) {
        return uint32(uint256(keccak256(abi.encodePacked(
            tokenSeed[tokenId],
            sevenWords[tokenId],
            previousNotesHash,
            globalState,
            tokenId
        ))));
    }

    // --- RANKING SYSTEM ---
    function getCurrentRank(uint256 tokenId) public view virtual returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _getCurrentRank(tokenId);
    }
    
    /// @notice Get total number of tokens minted
    function totalSupply() external view returns (uint256) {
        return totalMinted;
    }
    
    /// @notice Get song algorithm address
    function getSongAlgorithm() external view returns (address) {
        return address(songAlgorithm);
    }
    
    /// @notice Get music renderer address
    function getMusicRenderer() external view returns (address) {
        return address(musicRenderer);
    }
    
    /// @notice Get audio renderer address
    function getAudioRenderer() external view returns (address) {
        return address(audioRenderer);
    }
    
    function _getCurrentRank(uint256 tokenId) private view returns (uint256 rank) {
        uint256 tokenPoints = points[tokenId];
        uint256 tokenBase = basePermutation[tokenId];
        
        for (uint256 i = 1; i <= totalMinted; i++) {
            if (i == tokenId) continue;
            
            uint256 otherPoints = points[i];
            uint256 otherBase = basePermutation[i];
            
            bool comesBeforeUs = false;
            if (otherPoints > 0 && tokenPoints > 0) {
                if (otherPoints > tokenPoints) {
                    comesBeforeUs = true;
                } else if (otherPoints == tokenPoints) {
                    if (otherBase < tokenBase) {
                        comesBeforeUs = true;
                    } else if (otherBase == tokenBase && i < tokenId) {
                        comesBeforeUs = true;
                    }
                }
            } else if (otherPoints > 0 && tokenPoints == 0) {
                comesBeforeUs = true;
            } else if (otherPoints == 0 && tokenPoints == 0) {
                if (i < tokenId) {
                    comesBeforeUs = true;
                }
            }
            
            if (comesBeforeUs) {
                rank++;
            }
        }
    }
    
    /// @notice Test-only function to earn points
    function earnPoints(uint256 tokenId, uint256 amount) external {
        require(_ownerOf(tokenId) == msg.sender, "Not token owner");
        points[tokenId] += amount;
        emit PointsApplied(tokenId, amount, points[tokenId], "Manual");
    }

    // --- TOKEN URI ---
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        bool isRevealed = revealed[tokenId];
        
        string memory image;
        string memory animationUrl = "";
        string memory description;
        
        if (!isRevealed) {
            // Pre-reveal: Use countdown renderer (library)
            uint256 revealTime = _jan1Timestamp(revealYear);
            uint256 blocksRemaining = (revealTime > block.timestamp) 
                ? (revealTime - block.timestamp) / 12
                : 0;
            
            uint256 closenessBps = 10000;
            uint256 startTime = _jan1Timestamp(START_YEAR);
            if (revealTime > block.timestamp && block.timestamp >= startTime) {
                uint256 totalTime = revealTime - startTime;
                uint256 elapsed = block.timestamp - startTime;
                if (totalTime > 0) {
                    closenessBps = (elapsed * 10000) / totalTime;
                }
            } else if (block.timestamp < startTime) {
                // Before START_YEAR, closeness is 0
                closenessBps = 0;
            }
            
            RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
                tokenId: tokenId,
                rank: rank,
                revealYear: revealYear,
                closenessBps: closenessBps > 10000 ? 10000 : closenessBps,
                blocksDisplay: blocksRemaining,
                seed: tokenSeed[tokenId],
                nowTs: block.timestamp
            });
            
            image = CountdownRenderer.render(ctx);
            
            string memory wordsText = sevenWordsText[tokenId];
            description = bytes(wordsText).length > 0 
                ? wordsText 
                : string(abi.encodePacked(
                    "Every Two Million Blocks token #", tokenId.toString(),
                    " will reveal on Jan 1, ", revealYear.toString(), " UTC"
                  ));
        } else {
            // Post-reveal: Use music renderer + audio renderer
            ISongAlgorithm.Event memory lead = revealedLeadNote[tokenId];
            ISongAlgorithm.Event memory bass = revealedBassNote[tokenId];
            
            string memory svgContent;
            if (address(musicRenderer) != address(0)) {
                try musicRenderer.render(IMusicRenderer.BeatData({
                    tokenId: tokenId,
                    beat: rank,
                    year: revealYear,
                    leadPitch: lead.pitch,
                    leadDuration: lead.duration,
                    bassPitch: bass.pitch,
                    bassDuration: bass.duration
                })) returns (string memory svg) {
                    svgContent = svg;
                    // Convert raw SVG to data URI
                    image = string(abi.encodePacked(
                        "data:image/svg+xml;base64,",
                        Base64.encode(bytes(svg))
                    ));
                } catch {
                    svgContent = _buildFallbackSVG(tokenId, "Music renderer error");
                    image = svgContent; // Already a data URI
                }
            } else {
                svgContent = _buildFallbackSVG(tokenId, "Music renderer not set");
                image = svgContent; // Already a data URI
            }
            
            if (address(audioRenderer) != address(0)) {
                try audioRenderer.generateAudioHTML(
                    lead.pitch,
                    bass.pitch,
                    revealBlockTimestamp[tokenId],
                    svgContent
                ) returns (string memory html) {
                    animationUrl = html;
                } catch {
                    // Audio is optional, don't fail if it doesn't work
                }
            }
            
            string memory wordsText = sevenWordsText[tokenId];
            description = bytes(wordsText).length > 0 
                ? wordsText 
                : string(abi.encodePacked(
                    "Every Two Million Blocks token #", tokenId.toString(),
                    " - Year ", revealYear.toString(),
                    ". Continuous organ tones ring since reveal."
                  ));
        }
        
        // Build metadata JSON with note-based name for revealed tokens
        string memory name;
        if (isRevealed) {
            // Format: "G4+Eb2 [67+39]" (note names + MIDI)
            ISongAlgorithm.Event memory lead = revealedLeadNote[tokenId];
            ISongAlgorithm.Event memory bass = revealedBassNote[tokenId];
            name = string(abi.encodePacked(
                _midiToNoteName(lead.pitch),
                "+",
                _midiToNoteName(bass.pitch),
                " [",
                _int16ToString(lead.pitch),
                "+",
                _int16ToString(bass.pitch),
                "]"
            ));
        } else {
            name = string(abi.encodePacked(
                "Every Two Million Blocks #", tokenId.toString(),
                " - Year ", revealYear.toString()
            ));
        }
        
        string memory json = string(abi.encodePacked(
            '{"name":"', name,
            '","description":"', description,
            '","image":"', image, '"'
        ));
        
        if (bytes(animationUrl).length > 0) {
            json = string(abi.encodePacked(json, ',"animation_url":"', animationUrl, '"'));
        }
        
        // Add attributes
        json = string(abi.encodePacked(
            json,
            ',"attributes":[',
            '{"trait_type":"Year","value":', revealYear.toString(), '},',
            '{"trait_type":"Queue Rank","value":', rank.toString(), '},',
            '{"trait_type":"Points","value":', points[tokenId].toString(), '}'
        ));
        
        if (isRevealed) {
            json = string(abi.encodePacked(
                json,
                ',{"trait_type":"Lead Pitch (MIDI)","value":', _int16ToString(revealedLeadNote[tokenId].pitch), '}',
                ',{"trait_type":"Lead Duration","value":', uint256(revealedLeadNote[tokenId].duration).toString(), '}',
                ',{"trait_type":"Bass Pitch (MIDI)","value":', _int16ToString(revealedBassNote[tokenId].pitch), '}',
                ',{"trait_type":"Bass Duration","value":', uint256(revealedBassNote[tokenId].duration).toString(), '}'
            ));
        }
        
        json = string(abi.encodePacked(json, ']}'));
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }
    
    function _buildFallbackSVG(uint256 tokenId, string memory message) private pure returns (string memory) {
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">',
            '<rect width="100%" height="100%" fill="#000"/>',
            '<text x="300" y="300" text-anchor="middle" fill="#fff" font-size="20">',
            'Token #', tokenId.toString(),
            '</text>',
            '<text x="300" y="330" text-anchor="middle" fill="#fff" font-size="14">',
            message,
            '</text>',
            '</svg>'
        ));
        
        return string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(svg))
        ));
    }
    
    function _int16ToString(int16 value) private pure returns (string memory) {
        if (value >= 0) {
            return uint256(uint16(value)).toString();
        } else {
            return string(abi.encodePacked("-", uint256(uint16(-value)).toString()));
        }
    }
    
    /// @notice Convert MIDI pitch to note name (e.g., 60 -> "C4", 67 -> "G4")
    function _midiToNoteName(int16 midi) private pure returns (string memory) {
        if (midi == -1) return "REST";
        
        string[12] memory notes = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
        uint256 midiUint = uint256(int256(midi));
        uint256 pitchClass = midiUint % 12;
        int16 octave = int16(int256(midiUint / 12) - 1);
        
        return string(abi.encodePacked(
            notes[pitchClass],
            _int16ToString(octave)
        ));
    }
    
    // --- UTC DATE CALCULATION ---
    function _jan1Timestamp(uint256 year) internal view virtual returns (uint256) {
        require(year >= 1970, "Year before Unix epoch");
        uint256 dayCount = 0;
        for (uint256 y = 1970; y < year; y++) {
            dayCount += _isLeapYear(y) ? 366 : 365;
        }
        return dayCount * 1 days;
    }
    
    function _isLeapYear(uint256 year) private pure returns (bool) {
        if (year % 400 == 0) return true;
        if (year % 100 == 0) return false;
        if (year % 4 == 0) return true;
        return false;
    }
    
    // --- CROSS-CHAIN POINTS (STUBS FOR NOW) ---
    function applyCheckpointFromBase(bytes calldata) external {
        require(msg.sender == baseMessenger, "Not Base messenger");
        // Implementation TBD
    }
    
    function applyCheckpointFromOptimism(bytes calldata) external {
        require(msg.sender == optimismMessenger, "Not Optimism messenger");
        // Implementation TBD
    }
    
    function applyCheckpointFromArbitrum(bytes calldata) external {
        require(msg.sender == arbitrumInbox, "Not Arbitrum inbox");
        // Implementation TBD
    }
    
    function applyCheckpointFromZora(bytes calldata) external {
        require(msg.sender == zoraMessenger, "Not Zora messenger");
        // Implementation TBD
    }
}
