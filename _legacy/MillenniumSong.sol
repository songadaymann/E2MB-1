// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// ✅ Use the FULL library (V3 lead with rests + V2 bass without rests)
import "./SongAlgorithm.sol";
import "../render/post/MusicRenderer.sol";
import "../render/post/AudioRenderer.sol";
import "../render/pre/CountdownRenderer.sol";

/**
 * @title MillenniumSong
 * @dev Minimal ERC721 wired to the full SongAlgorithm for quick Hardhat testing.
 *      tokenURI returns a tiny JSON with ABC in animation_url (data: URL)
 *      abcForBeat() lets you query any beat directly.
 */
contract MillenniumSong is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant START_YEAR = 2026;

    uint256 public totalMinted;
    mapping(uint256 => uint32) public tokenSeed; // per-token deterministic seed
    
    // --- DYNAMIC RANKING ---
    mapping(uint256 => uint256) public points; // Points per token
    mapping(uint256 => uint256) public basePermutation; // VRF order (placeholder: tokenId)
    
    // --- CROSS-CHAIN MESSENGERS (L2 → L1) ---
    // Mainnet addresses (will be different on testnets)
    address public baseMessenger = 0x4200000000000000000000000000000000000007; // Base L1CrossDomainMessenger
    address public optimismMessenger = 0x4200000000000000000000000000000000000007; // OP L1CrossDomainMessenger
    address public arbitrumInbox; // Arbitrum Inbox (set after deploy)
    address public zoraMessenger = 0x4200000000000000000000000000000000000007; // Zora L1CrossDomainMessenger
    
    // L1 Burn handling
    mapping(address => uint256) public eligibleL1Assets; // NFT contract => base value
    uint256[12] public monthWeights; // Month weighting (Jan=100, Dec=60)
    
    // --- REVEAL SYSTEM ---
    mapping(uint256 => bool) public revealed;
    mapping(uint256 => SongAlgorithm.Event) public revealedLeadNote;
    mapping(uint256 => SongAlgorithm.Event) public revealedBassNote;
    mapping(uint256 => uint256) public revealBlockTimestamp; // When it was revealed
    
    // --- SEED COMPONENTS ---
    mapping(uint256 => bytes32) public sevenWords; // 7-word commitment per token
    bytes32 public previousNotesHash; // Rolling hash of all revealed notes
    bytes32 public globalState; // Collection-level entropy
    
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

    constructor() ERC721("MillenniumSong", "MSONG") Ownable(msg.sender) {
        // Initialize month weights (scaled by 100)
        monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    }

    // Owner-only mint, pass a seed to keep results reproducible (0 => auto-seed)
    function mint(address to, uint32 seed) external onlyOwner returns (uint256 tokenId) {
        require(totalMinted < MAX_SUPPLY, "sold out");
        tokenId = ++totalMinted;
        _safeMint(to, tokenId);
        tokenSeed[tokenId] = (seed == 0)
            ? uint32(uint256(keccak256(abi.encodePacked(block.timestamp, to, tokenId))))
            : seed;
        
        // Initialize base permutation (will be VRF-based in production)
        basePermutation[tokenId] = tokenId;
    }
    
    /// @notice Set the seven words for a token (owner can do this before reveal)
    /// @dev In production, this would be set at mint time by the minter
    function setSevenWords(uint256 tokenId, bytes32 words) external {
        require(_ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!revealed[tokenId], "Already revealed");
        sevenWords[tokenId] = words;
    }
    
    /// @notice Initialize or update global state (owner only, for testing)
    function setGlobalState(bytes32 newState) external onlyOwner {
        globalState = newState;
    }

    // --- REVEAL FUNCTION ---
    /// @notice Reveal a token's note when its reveal time arrives
    /// @dev Anyone can call this once the token's reveal time (Jan 1 of its year) has passed
    /// @param tokenId The token to reveal
    function revealNote(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        
        // Calculate reveal time (Jan 1 00:00:00 UTC of the token's reveal year)
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        uint256 revealTime = _jan1Timestamp(revealYear);
        
        require(block.timestamp >= revealTime, "Not reveal time yet");
        
        _performReveal(tokenId, rank);
    }
    
    /// @notice TEST ONLY: Force reveal a token (bypasses time check)
    /// @dev Owner only, for testnet deployment
    function forceReveal(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(!revealed[tokenId], "Already revealed");
        
        uint256 rank = getCurrentRank(tokenId);
        _performReveal(tokenId, rank);
    }
    
    /// @dev Internal reveal logic (shared by revealNote and forceReveal)
    function _performReveal(uint256 tokenId, uint256 rank) private {
        // Mark as revealed with current timestamp (locks in entropy)
        revealed[tokenId] = true;
        revealBlockTimestamp[tokenId] = block.timestamp;
        
        // Compute final seed from all entropy sources
        uint32 beat = uint32(rank);
        uint32 seed = _computeRevealSeed(tokenId);
        
        (SongAlgorithm.Event memory lead, SongAlgorithm.Event memory bass) = 
            SongAlgorithm.generateBeat(beat, seed);
        
        // Store the revealed notes
        revealedLeadNote[tokenId] = lead;
        revealedBassNote[tokenId] = bass;
        
        // Update the rolling previousNotesHash for future reveals
        _updatePreviousNotesHash(tokenId);
        
        emit NoteRevealed(tokenId, beat, lead.pitch, bass.pitch, block.timestamp);
    }
    
    // Convenience: get ABC for any beat for a token (purely view)
    function abcForBeat(uint256 tokenId, uint32 beat) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "no token");
        return SongAlgorithm.generateAbcBeat(beat, tokenSeed[tokenId]);
    }

    // Optional: get raw events (lead/bass) for inspection in tests
    function eventsForBeat(uint256 tokenId, uint32 beat)
        external
        view
        returns (int16 leadPitch, uint16 leadDur, int16 bassPitch, uint16 bassDur)
    {
        require(_ownerOf(tokenId) != address(0), "no token");
        (SongAlgorithm.Event memory L, SongAlgorithm.Event memory B) =
            SongAlgorithm.generateBeat(beat, tokenSeed[tokenId]);
        return (L.pitch, L.duration, B.pitch, B.duration);
    }

    /// @notice Get the full metadata JSON with SVG image and ABC animation_url
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        
        string memory svg;
        string memory animationUrl;
        string memory attributes;
        
        if (revealed[tokenId]) {
            // POST-REVEAL: Show musical notation + continuous audio
            MusicRenderer.BeatData memory data = MusicRenderer.BeatData({
                tokenId: tokenId,
                beat: uint32(rank),
                year: revealYear,
                leadPitch: revealedLeadNote[tokenId].pitch,
                leadDuration: revealedLeadNote[tokenId].duration,
                bassPitch: revealedBassNote[tokenId].pitch,
                bassDuration: revealedBassNote[tokenId].duration
            });
            
            svg = MusicRenderer.render(data);
            
            // Generate continuous audio HTML (organ-style synthesis)
            animationUrl = AudioRenderer.generateAudioHTML(
                revealedLeadNote[tokenId].pitch,
                revealedBassNote[tokenId].pitch,
                revealBlockTimestamp[tokenId],
                tokenId,
                revealYear
            );
            
            // Convert sevenWords from bytes32 to string (simplified)
            string memory sevenWordsStr = _bytes32ToString(sevenWords[tokenId]);
            
            attributes = string(abi.encodePacked(
                '{"trait_type":"Year","value":', Strings.toString(revealYear), '},',
                '{"trait_type":"Reveal Timestamp","value":', Strings.toString(revealBlockTimestamp[tokenId]), '},',
                '{"trait_type":"Seven Words","value":"', sevenWordsStr, '"},',
                '{"trait_type":"Lead Pitch (MIDI)","value":', _int16ToString(revealedLeadNote[tokenId].pitch), '},',
                '{"trait_type":"Lead Duration","value":', Strings.toString(revealedLeadNote[tokenId].duration), '},',
                '{"trait_type":"Bass Pitch (MIDI)","value":', _int16ToString(revealedBassNote[tokenId].pitch), '},',
                '{"trait_type":"Bass Duration","value":', Strings.toString(revealedBassNote[tokenId].duration), '},',
                '{"trait_type":"Queue Rank","value":', Strings.toString(rank), '},',
                '{"trait_type":"Points","value":', Strings.toString(points[tokenId]), '}'
            ));
        } else {
            // PRE-REVEAL: Show countdown
            svg = ""; // TODO: Wire up CountdownRenderer
            animationUrl = "";
            
            attributes = string(abi.encodePacked(
                '{"trait_type":"Year","value":', Strings.toString(revealYear), '},',
                '{"trait_type":"Status","value":"Unrevealed"},',
                '{"trait_type":"Queue Rank","value":', Strings.toString(rank), '},',
                '{"trait_type":"Points","value":', Strings.toString(points[tokenId]), '}'
            ));
        }
        
        bytes memory json = abi.encodePacked(
            '{"name":"Millennium Song #', Strings.toString(tokenId), ' - Year ', Strings.toString(revealYear), '",',
            '"description":"Note event ', revealed[tokenId] ? 'revealed' : 'awaiting reveal', '. Continuous organ tones ring since reveal.",',
            '"image":"', svg, '",',
            '"animation_url":"', animationUrl, '",',
            '"attributes":[', attributes, ']}'
        );
        
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }
    
    /// @notice Get current rank for a token (points-based ordering)
    function getCurrentRank(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = 0;
        uint256 tokenPoints = points[tokenId];
        uint256 tokenBase = basePermutation[tokenId];
        
        // Count how many tokens rank ahead of this one
        for (uint256 i = 1; i <= totalMinted; i++) {
            if (i == tokenId) continue;
            
            uint256 otherPoints = points[i];
            uint256 otherBase = basePermutation[i];
            
            // Other token ranks ahead if:
            // 1. It has more points, OR
            // 2. Same points but lower basePermutation
            if (otherPoints > tokenPoints || 
                (otherPoints == tokenPoints && otherBase < tokenBase)) {
                rank++;
            }
        }
        
        return rank;
    }

    // --- SEED COMPUTATION ---
    
    /// @notice Compute the reveal seed from all entropy sources
    /// @dev Combines: previousNotesHash + block.timestamp + tokenId + sevenWords + globalState
    /// @param tokenId The token being revealed
    /// @return seed The 32-bit seed for SongAlgorithm
    function _computeRevealSeed(uint256 tokenId) internal view returns (uint32) {
        bytes32 hash = keccak256(abi.encodePacked(
            previousNotesHash,      // History of all previous notes
            block.timestamp,        // Entropy from reveal moment
            tokenId,                // Token-specific input
            sevenWords[tokenId],    // Owner's committed words
            globalState             // Collection-level state
        ));
        
        // Take first 32 bits of the hash
        return uint32(uint256(hash));
    }
    
    /// @notice Update the previousNotesHash after a reveal
    /// @dev Called internally after storing revealed notes
    /// @param tokenId The token that was just revealed
    function _updatePreviousNotesHash(uint256 tokenId) internal {
        // Hash combines: old hash + new lead + new bass
        previousNotesHash = keccak256(abi.encodePacked(
            previousNotesHash,
            revealedLeadNote[tokenId].pitch,
            revealedLeadNote[tokenId].duration,
            revealedBassNote[tokenId].pitch,
            revealedBassNote[tokenId].duration
        ));
    }

    // --- CROSS-CHAIN POINTS SYSTEM ---
    
    /// @notice Receive checkpoint from Base L2
    /// @dev Called by Base's L1CrossDomainMessenger
    function applyCheckpointFromBase(bytes calldata payload) external {
        require(msg.sender == baseMessenger, "Not Base messenger");
        _applyCheckpoint(payload, "Base");
    }
    
    /// @notice Receive checkpoint from Optimism L2
    function applyCheckpointFromOptimism(bytes calldata payload) external {
        require(msg.sender == optimismMessenger, "Not Optimism messenger");
        _applyCheckpoint(payload, "Optimism");
    }
    
    /// @notice Receive checkpoint from Arbitrum L2
    function applyCheckpointFromArbitrum(bytes calldata payload) external {
        require(msg.sender == arbitrumInbox, "Not Arbitrum inbox");
        _applyCheckpoint(payload, "Arbitrum");
    }
    
    /// @notice Receive checkpoint from Zora L2
    function applyCheckpointFromZora(bytes calldata payload) external {
        require(msg.sender == zoraMessenger, "Not Zora messenger");
        _applyCheckpoint(payload, "Zora");
    }
    
    /// @notice Internal function to apply points from L2 checkpoint
    function _applyCheckpoint(bytes calldata payload, string memory chain) internal {
        (address[] memory addresses, uint256[] memory pointsDeltas) = 
            abi.decode(payload, (address[], uint256[]));
        
        require(addresses.length == pointsDeltas.length, "Length mismatch");
        
        uint256 totalPoints;
        for (uint256 i = 0; i < addresses.length; i++) {
            // In production: map address to tokenId (requires assignment mechanism)
            // For now: simplified - assume address owns tokenId matching their position
            // TODO: Add proper address → tokenId mapping
            
            uint256 tokenId = i + 1; // Placeholder
            if (_ownerOf(tokenId) == addresses[i]) {
                points[tokenId] += pointsDeltas[i];
                totalPoints += pointsDeltas[i];
                
                emit PointsApplied(tokenId, pointsDeltas[i], points[tokenId], chain);
            }
        }
        
        emit CheckpointReceived(chain, addresses.length, totalPoints);
    }
    
    /// @notice Handle L1 burns directly (for Ethereum-based NFTs)
    /// @param nftContract The NFT contract being burned
    /// @param tokenId The token being burned
    /// @param msongTokenId The Millennium Song token to credit points to
    function burnOnL1(address nftContract, uint256 tokenId, uint256 msongTokenId) external {
        require(eligibleL1Assets[nftContract] > 0, "Asset not eligible");
        require(_ownerOf(msongTokenId) == msg.sender, "Not token owner");
        
        // Transfer NFT to this contract (acts as burn)
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        // Calculate points with month weighting
        uint256 baseValue = eligibleL1Assets[nftContract];
        uint256 month = _getCurrentMonth();
        uint256 weight = monthWeights[month];
        uint256 earnedPoints = (baseValue * weight) / 100;
        
        // Apply points
        points[msongTokenId] += earnedPoints;
        
        emit PointsApplied(msongTokenId, earnedPoints, points[msongTokenId], "L1");
    }
    
    // --- ADMIN FUNCTIONS FOR POINTS SYSTEM ---
    
    /// @notice Add eligible L1 asset for burning
    function addEligibleL1Asset(address nftContract, uint256 baseValue) external onlyOwner {
        require(nftContract != address(0), "Invalid address");
        eligibleL1Assets[nftContract] = baseValue;
    }
    
    /// @notice Update messenger addresses (for testnet/mainnet switching)
    function setMessengers(
        address _base,
        address _optimism,
        address _arbitrum,
        address _zora
    ) external onlyOwner {
        baseMessenger = _base;
        optimismMessenger = _optimism;
        arbitrumInbox = _arbitrum;
        zoraMessenger = _zora;
    }
    
    /// @notice Update month weights
    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }

    // --- helpers ---
    
    /// @notice Convert bytes32 to readable string (simplified - just shows hex)
    function _bytes32ToString(bytes32 data) internal pure returns (string memory) {
        if (data == bytes32(0)) return "";
        
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        
        for (uint256 i = 0; i < 32; i++) {
            str[i*2] = alphabet[uint8(data[i] >> 4)];
            str[1+i*2] = alphabet[uint8(data[i] & 0x0f)];
        }
        
        return string(str);
    }
    
    /// @notice Convert int16 to string (handles negatives for pitch)
    function _int16ToString(int16 value) internal pure returns (string memory) {
        if (value == -1) return "-1"; // Rest
        if (value == 0) return "0";
        
        bool negative = value < 0;
        uint16 absValue = uint16(negative ? -value : value);
        
        uint256 digits = 0;
        uint16 temp = absValue;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(negative ? digits + 1 : digits);
        uint256 index = buffer.length;
        
        while (absValue != 0) {
            index--;
            buffer[index] = bytes1(uint8(48 + (absValue % 10)));
            absValue /= 10;
        }
        
        if (negative) {
            buffer[0] = "-";
        }
        
        return string(buffer);
    }

    // very rough UTC year extractor for local testing (not leap-year precise; fine for now)
    function _utcYear(uint256 ts) internal pure returns (uint32) {
        // 1970 + floor(seconds / avgYearSeconds)
        // Using 365 days avg; this is just to drive a changing "beat" in dev.
        return uint32(1970 + (ts / (365 days)));
    }
    
    /// @notice Get Unix timestamp for Jan 1, 00:00:00 UTC of a given year
    /// @dev Proper Gregorian leap-year calculation
    function _jan1Timestamp(uint256 year) internal pure returns (uint256) {
        require(year >= 1970, "Year must be >= 1970");
        
        uint256 dayCount = 0;
        
        // Count days from 1970 to target year
        for (uint256 y = 1970; y < year; y++) {
            if (_isLeapYear(y)) {
                dayCount += 366;
            } else {
                dayCount += 365;
            }
        }
        
        return dayCount * 1 days;
    }
    
    /// @notice Check if a year is a leap year (Gregorian calendar rules)
    /// @dev Leap if: divisible by 4 AND (not divisible by 100 OR divisible by 400)
    function _isLeapYear(uint256 year) internal pure returns (bool) {
        if (year % 4 != 0) return false;        // Not divisible by 4 → not leap
        if (year % 100 != 0) return true;       // Divisible by 4, not by 100 → leap
        if (year % 400 == 0) return true;       // Divisible by 400 → leap
        return false;                           // Divisible by 100 but not 400 → not leap
    }
    
    /// @notice Get current month (0-11) for month weighting
    function _getCurrentMonth() internal view returns (uint256) {
        // Simplified: extract month from timestamp
        // In production, use proper UTC calendar math
        uint256 daysFromEpoch = block.timestamp / 1 days;
        uint256 approxMonth = (daysFromEpoch % 365) / 30;
        return approxMonth > 11 ? 11 : approxMonth;
    }
}
