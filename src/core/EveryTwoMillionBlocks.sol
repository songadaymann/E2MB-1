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
import "../interfaces/IPointsManager.sol";
import "../interfaces/IPointsAggregator.sol";
import "../interfaces/IVRFCoordinatorV2_5.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// Countdown renderer (external contract)
import "../render/IRenderTypes.sol";

interface ICountdownRenderer {
    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory);
}

interface ICountdownHtmlRenderer {
    function render(RenderTypes.RenderCtx memory ctx) external view returns (string memory);
}

/**
 * @title EveryTwoMillionBlocks
 * @dev ERC-721 NFT with external rendering contracts for modularity and size optimization
 *      Uses orchestrator pattern to stay under 24KB contract size limit
 */
contract EveryTwoMillionBlocks is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 public constant START_YEAR = 2026;

    uint256 public totalMinted;
    bool public mintEnabled;
    uint256 public mintPrice;
    address payable public payoutAddress;
    mapping(uint256 => uint32) public tokenSeed;
    
    // --- EXTERNAL CONTRACT ADDRESSES ---
    ISongAlgorithm public songAlgorithm;
    IMusicRenderer public musicRenderer;
    IAudioRenderer public audioRenderer;
    IPointsManager public pointsManager;
    IPointsAggregator public pointsAggregator;
    ICountdownRenderer public countdownRenderer;
    ICountdownHtmlRenderer public countdownHtmlRenderer;
    address public permutationScript;

    struct PreRevealRenderer {
        ICountdownRenderer svgRenderer;
        ICountdownHtmlRenderer htmlRenderer;
        bool active;
    }

    mapping(uint256 => PreRevealRenderer) private preRevealRenderers;
    uint256 public preRevealRendererCount = 1; // slot 0 reserved for countdown
    uint256 public defaultPreRevealRendererId;
    bool public preRevealRegistryFrozen;

    mapping(uint256 => uint256) public tokenPreRevealChoice;
    mapping(uint256 => bool) public tokenPreRevealChoiceSet;

    IVRFCoordinatorV2_5 public vrfCoordinator;
    bytes32 public vrfKeyHash;
    uint256 public vrfSubscriptionId;
    uint16 public vrfMinConfirmations;
    uint32 public vrfCallbackGasLimit;
    uint32 public vrfNumWords = 1;
    uint256 public vrfRequestId;
    bool public vrfRequestInFlight;
    bytes32 public permutationSeed;
    bool public permutationSeedFulfilled;
    
    bool public renderersFinalized;
    
    // --- DYNAMIC RANKING ---
    mapping(uint256 => uint256) public basePermutation;
    bool public permutationFinalized;
    uint256 public permutationEntryCount;
    uint256 public permutationChunkCount;
    
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
    
    event RenderersUpdated(address music, address audio, address countdown);
    event RenderersFinalized();
    event PointsManagerUpdated(address pointsManager);
    event PointsAggregatorUpdated(address pointsAggregator);
    event RevealPrepared(uint256 indexed tokenId, uint32 beat, bytes32 words);
    event RevealCancelled(uint256 indexed tokenId);
    event PermutationChunkIngested(uint256 indexed chunkId, uint256 count);
    event PermutationFinalized(uint256 totalEntries);
    event VRFConfigUpdated(
        address indexed coordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint16 minConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    );
    event PermutationSeedRequested(uint256 indexed requestId);
    event PermutationSeedFulfilled(uint256 indexed requestId, bytes32 seed);
    event PermutationSeedManuallySet(bytes32 seed);
    event PreRevealRendererRegistered(uint256 indexed rendererId, address svgRenderer, address htmlRenderer, bool active);
    event PreRevealRendererUpdated(uint256 indexed rendererId, address svgRenderer, address htmlRenderer, bool active);
    event DefaultPreRevealRendererSet(uint256 indexed rendererId);
    event PreRevealRegistryFrozen();
    event TokenPreRevealRendererSelected(uint256 indexed tokenId, uint256 indexed rendererId, address indexed caller);
    event TokenPreRevealRendererCleared(uint256 indexed tokenId, address indexed caller);

    constructor() ERC721("Every Two Million Blocks", "E2MB") Ownable(msg.sender) {
        preRevealRenderers[0].active = true;
        defaultPreRevealRendererId = 0;
    }
    
    // --- RENDERER MANAGEMENT ---
    modifier renderersNotFinalized() {
        require(!renderersFinalized, "Renderers finalized");
        _;
    }

    modifier preRevealRegistryNotFrozen() {
        require(!preRevealRegistryFrozen, "Pre-reveal registry frozen");
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
    
    /// @notice Set points manager address (only before finalization)
    function setPointsManager(address _pointsManager) external onlyOwner renderersNotFinalized {
        pointsManager = IPointsManager(_pointsManager);
        emit PointsManagerUpdated(_pointsManager);
    }

    /// @notice Set points aggregator address (only before finalization)
    function setPointsAggregator(address _pointsAggregator) external onlyOwner renderersNotFinalized {
        pointsAggregator = IPointsAggregator(_pointsAggregator);
        emit PointsAggregatorUpdated(_pointsAggregator);
    }

    /// @notice Set permutation script storage address (SSTORE2 blob) before finalization
    function setPermutationScript(address _script) external onlyOwner renderersNotFinalized {
        permutationScript = _script;
    }

    /// @notice Configure Chainlink VRF settings (only before finalization)
    function configureVRF(
        address _coordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint16 _minConfirmations,
        uint32 _callbackGasLimit,
        uint32 _numWords
    ) external onlyOwner renderersNotFinalized {
        require(_coordinator != address(0), "Invalid coordinator");
        require(_keyHash != bytes32(0), "Invalid key hash");
        require(_subscriptionId != 0, "Invalid subscription");
        require(_minConfirmations > 0, "Confirmations=0");
        require(_callbackGasLimit > 0, "Callback gas=0");
        require(_numWords > 0, "Num words=0");

        vrfCoordinator = IVRFCoordinatorV2_5(_coordinator);
        vrfKeyHash = _keyHash;
        vrfSubscriptionId = _subscriptionId;
        vrfMinConfirmations = _minConfirmations;
        vrfCallbackGasLimit = _callbackGasLimit;
        vrfNumWords = _numWords;

        emit VRFConfigUpdated(_coordinator, _keyHash, _subscriptionId, _minConfirmations, _callbackGasLimit, _numWords);
    }

    /// @notice Manually set the permutation seed (testing fallback)
    function setPermutationSeedManual(bytes32 seed) external onlyOwner renderersNotFinalized {
        permutationSeed = seed;
        permutationSeedFulfilled = true;
        vrfRequestInFlight = false;
        vrfRequestId = 0;
        emit PermutationSeedManuallySet(seed);
    }

    /// @notice Request randomness from Chainlink VRF to seed the permutation shuffle
    function requestPermutationSeed() external onlyOwner renderersNotFinalized {
        require(address(vrfCoordinator) != address(0), "VRF not configured");
        require(!vrfRequestInFlight, "Request in flight");

        uint256 requestId = vrfCoordinator.requestRandomWords(
            IVRFCoordinatorV2_5.RandomWordsRequest({
                keyHash: vrfKeyHash,
                subId: vrfSubscriptionId,
                requestConfirmations: vrfMinConfirmations,
                callbackGasLimit: vrfCallbackGasLimit,
                numWords: vrfNumWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );

        vrfRequestId = requestId;
        vrfRequestInFlight = true;
        permutationSeedFulfilled = false;

        emit PermutationSeedRequested(requestId);
    }
    
    /// @notice Set countdown renderer addresses (slot 0 in the registry)
    function setCountdownRenderer(address _countdownRenderer) external onlyOwner preRevealRegistryNotFrozen {
        require(_countdownRenderer != address(0), "Invalid countdown renderer");
        PreRevealRenderer storage slotZero = preRevealRenderers[0];
        slotZero.svgRenderer = ICountdownRenderer(_countdownRenderer);
        slotZero.active = true;
        countdownRenderer = ICountdownRenderer(_countdownRenderer);
        emit PreRevealRendererUpdated(0, _countdownRenderer, address(slotZero.htmlRenderer), true);
    }
    
    /// @notice Set countdown HTML renderer address (slot 0 in the registry)
    function setCountdownHtmlRenderer(address _countdownHtmlRenderer) external onlyOwner preRevealRegistryNotFrozen {
        PreRevealRenderer storage slotZero = preRevealRenderers[0];
        slotZero.htmlRenderer = ICountdownHtmlRenderer(_countdownHtmlRenderer);
        countdownHtmlRenderer = ICountdownHtmlRenderer(_countdownHtmlRenderer);
        emit PreRevealRendererUpdated(0, address(slotZero.svgRenderer), _countdownHtmlRenderer, slotZero.active);
    }

    /// @notice Register a new pre-reveal renderer slot (returns the slot id)
    function addPreRevealRenderer(
        address svgRenderer,
        address htmlRenderer,
        bool active
    ) external onlyOwner preRevealRegistryNotFrozen returns (uint256 rendererId) {
        require(svgRenderer != address(0), "SVG renderer required");

        rendererId = preRevealRendererCount;
        preRevealRendererCount += 1;

        preRevealRenderers[rendererId] = PreRevealRenderer({
            svgRenderer: ICountdownRenderer(svgRenderer),
            htmlRenderer: ICountdownHtmlRenderer(htmlRenderer),
            active: active
        });

        emit PreRevealRendererRegistered(rendererId, svgRenderer, htmlRenderer, active);
    }

    /// @notice Update renderer addresses and status for an existing slot
    function updatePreRevealRenderer(
        uint256 rendererId,
        address svgRenderer,
        address htmlRenderer,
        bool active
    ) public onlyOwner preRevealRegistryNotFrozen {
        require(rendererId < preRevealRendererCount, "Renderer does not exist");
        require(svgRenderer != address(0), "SVG renderer required");

        preRevealRenderers[rendererId] = PreRevealRenderer({
            svgRenderer: ICountdownRenderer(svgRenderer),
            htmlRenderer: ICountdownHtmlRenderer(htmlRenderer),
            active: active
        });

        emit PreRevealRendererUpdated(rendererId, svgRenderer, htmlRenderer, active);
    }

    /// @notice Set an existing slot as the default renderer for tokens without a manual choice
    function setDefaultPreRevealRenderer(uint256 rendererId) external onlyOwner preRevealRegistryNotFrozen {
        require(rendererId < preRevealRendererCount, "Renderer does not exist");
        PreRevealRenderer storage renderer = preRevealRenderers[rendererId];
        require(renderer.active, "Renderer inactive");
        require(address(renderer.svgRenderer) != address(0), "Renderer missing SVG");

        defaultPreRevealRendererId = rendererId;
        emit DefaultPreRevealRendererSet(rendererId);
    }

    /// @notice Irreversibly freeze the registry so no new slots or updates can occur
    function freezePreRevealRegistry() external onlyOwner preRevealRegistryNotFrozen {
        preRevealRegistryFrozen = true;
        emit PreRevealRegistryFrozen();
    }

    /// @notice Assign a renderer slot to a token (token owner or approved)
    function setTokenPreRevealRenderer(uint256 tokenId, uint256 rendererId) external {
        address tokenOwner = _ownerOf(tokenId);
        require(tokenOwner != address(0), "Token does not exist");
        require(_isAuthorized(tokenOwner, msg.sender, tokenId), "Not authorized");
        require(!revealed[tokenId], "Token already revealed");
        require(rendererId < preRevealRendererCount, "Renderer does not exist");

        PreRevealRenderer storage renderer = preRevealRenderers[rendererId];
        require(renderer.active, "Renderer inactive");
        require(address(renderer.svgRenderer) != address(0), "Renderer missing SVG");

        tokenPreRevealChoice[tokenId] = rendererId;
        tokenPreRevealChoiceSet[tokenId] = true;

        emit TokenPreRevealRendererSelected(tokenId, rendererId, msg.sender);
    }

    /// @notice Clear a token's manual renderer choice so it falls back to the default slot
    function clearTokenPreRevealRenderer(uint256 tokenId) external {
        address tokenOwner = _ownerOf(tokenId);
        require(tokenOwner != address(0), "Token does not exist");
        require(_isAuthorized(tokenOwner, msg.sender, tokenId), "Not authorized");
        if (!tokenPreRevealChoiceSet[tokenId]) {
            return;
        }

        delete tokenPreRevealChoice[tokenId];
        tokenPreRevealChoiceSet[tokenId] = false;

        emit TokenPreRevealRendererCleared(tokenId, msg.sender);
    }

    /// @notice View helper to inspect a renderer slot
    function getPreRevealRenderer(uint256 rendererId)
        external
        view
        returns (address svgRenderer, address htmlRenderer, bool active)
    {
        require(rendererId < preRevealRendererCount, "Renderer does not exist");
        PreRevealRenderer storage renderer = preRevealRenderers[rendererId];
        return (address(renderer.svgRenderer), address(renderer.htmlRenderer), renderer.active);
    }

    /// @notice View helper that returns the effective renderer for a token
    function getTokenPreRevealRenderer(uint256 tokenId) external view returns (uint256 rendererId, bool isCustom) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        if (tokenPreRevealChoiceSet[tokenId]) {
            return (tokenPreRevealChoice[tokenId], true);
        }
        return (defaultPreRevealRendererId, false);
    }
    
    /// @notice Finalize renderer addresses (one-way, cannot be changed after)
    function finalizeRenderers() external onlyOwner {
        renderersFinalized = true;
        emit RenderersFinalized();
    }

    // --- MINTING ---
    event MintStatusUpdated(bool enabled);
    event MintPriceUpdated(uint256 price);
    event PayoutAddressUpdated(address payout);

    function setMintEnabled(bool enabled) external onlyOwner {
        mintEnabled = enabled;
        emit MintStatusUpdated(enabled);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
        emit MintPriceUpdated(price);
    }

    function setPayoutAddress(address payable payout) external onlyOwner {
        require(payout != address(0), "Invalid payout");
        payoutAddress = payout;
        emit PayoutAddressUpdated(payout);
    }

    function mint(address to, uint32 seed) external onlyOwner returns (uint256 tokenId) {
        tokenId = _mintToken(to, seed);
    }

    function mintOpenEdition(uint32 seed) external payable returns (uint256 tokenId) {
        require(mintEnabled, "Mint disabled");
        require(msg.value >= mintPrice, "Insufficient payment");
        tokenId = _mintToken(msg.sender, seed);
        if (msg.value > mintPrice) {
            unchecked {
                payable(msg.sender).transfer(msg.value - mintPrice);
            }
        }
    }

    function _mintToken(address to, uint32 seed) internal returns (uint256 tokenId) {
        tokenId = ++totalMinted;
        _safeMint(to, tokenId);
        tokenSeed[tokenId] = (seed == 0)
            ? uint32(uint256(keccak256(abi.encodePacked(block.timestamp, to, tokenId))))
            : seed;

        basePermutation[tokenId] = tokenId - 1;
    }

    function withdraw() external onlyOwner {
        address payable recipient = payoutAddress;
        require(recipient != address(0), "Payout not set");
        recipient.transfer(address(this).balance);
    }
    /// @notice Ingest a batch of permutation entries before finalization
    function ingestPermutationChunk(
        uint256[] calldata tokenIds,
        uint256[] calldata permutationIndices
    ) external onlyOwner renderersNotFinalized {
        require(!permutationFinalized, "Permutation finalized");
        require(tokenIds.length == permutationIndices.length, "Length mismatch");
        uint256 length = tokenIds.length;
        require(length > 0, "Empty chunk");

        for (uint256 i = 0; i < length; i++) {
            basePermutation[tokenIds[i]] = permutationIndices[i];
        }

        unchecked {
            permutationEntryCount += length;
            permutationChunkCount += 1;
        }

        emit PermutationChunkIngested(permutationChunkCount, length);
    }

    /// @notice Finalize permutation data; irreversible
    function finalizePermutation() external onlyOwner renderersNotFinalized {
        require(!permutationFinalized, "Already finalized");
        require(permutationSeedFulfilled, "Permutation seed not ready");
        permutationFinalized = true;
        emit PermutationFinalized(permutationEntryCount);
    }
    
    /// @notice Set the seven words for a token (owner can do this before reveal)
    function setSevenWords(uint256 tokenId, string calldata wordsText) external {
        require(_ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!revealed[tokenId], "Already revealed");
        require(bytes(wordsText).length > 0, "Words required");
        sevenWords[tokenId] = keccak256(bytes(wordsText));
        sevenWordsText[tokenId] = wordsText;
    }

    function hasSevenWords(uint256 tokenId) public view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return bytes(sevenWordsText[tokenId]).length > 0;
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
        
        uint32 beat = pendingBeat[tokenId];

        // Mark as revealed
        revealed[tokenId] = true;
        revealBlockTimestamp[tokenId] = block.timestamp;
        
        // Compute seed using snapshotted words and current previousNotesHash
        uint32 seed = _computeRevealSeed(tokenId);
        
        // Generate music (external contract call)
        (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
            songAlgorithm.generateBeat(beat, seed);
        
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

        _notifyReveal(tokenId);
        
        emit NoteRevealed(tokenId, beat, lead.pitch, bass.pitch, block.timestamp);
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
        
        _notifyReveal(tokenId);
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

    function _notifyReveal(uint256 tokenId) private {
        if (address(pointsAggregator) != address(0)) {
            try pointsAggregator.onTokenRevealed(tokenId) {
                // no-op
            } catch {
                // swallow errors to avoid blocking reveal
            }
        }
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(msg.sender == address(vrfCoordinator), "Only VRF coordinator");
        _fulfillPermutationSeed(requestId, randomWords);
    }

    function _fulfillPermutationSeed(uint256 requestId, uint256[] memory randomWords) internal {
        require(vrfRequestInFlight, "No request");
        require(requestId == vrfRequestId, "Request mismatch");
        require(randomWords.length > 0, "Empty random words");

        bytes32 seed = keccak256(abi.encodePacked(randomWords));
        permutationSeed = seed;
        permutationSeedFulfilled = true;
        vrfRequestInFlight = false;
        vrfRequestId = requestId;

        emit PermutationSeedFulfilled(requestId, seed);
    }

    // --- RANKING SYSTEM ---
    
    /// @notice Get current rank for a token (0-indexed)
    /// @dev Delegates to PointsManager if set, otherwise falls back to tokenId order
    function getCurrentRank(uint256 tokenId) public view virtual returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        if (address(pointsManager) != address(0)) {
            return pointsManager.currentRankOf(tokenId);
        } else {
            // Fallback: simple tokenId-based ranking
            return tokenId - 1;
        }
    }
    
    /// @notice Get points for a token
    /// @dev Delegates to PointsManager if set, otherwise returns 0
    function getPoints(uint256 tokenId) public view returns (uint256) {
        if (address(pointsManager) != address(0)) {
            return pointsManager.pointsOf(tokenId);
        } else {
            return 0;
        }
    }
    
    /// @notice Get total number of tokens minted
    function totalSupply() external view returns (uint256) {
        return totalMinted;
    }

    /// @notice Returns true if the permutation seed has been set (via VRF or manual override)
    function hasPermutationSeed() external view returns (bool) {
        return permutationSeedFulfilled;
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

    // --- TOKEN URI ---
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 rank = getCurrentRank(tokenId);
        uint256 revealYear = START_YEAR + rank;
        bool isRevealed = revealed[tokenId];
        
        string memory image;
        string memory animationUrl = "";
        string memory description;
        string memory wordsText = sevenWordsText[tokenId];
        bool hasWords = bytes(wordsText).length > 0;
        
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

            uint256 preferredRendererId = tokenPreRevealChoiceSet[tokenId]
                ? tokenPreRevealChoice[tokenId]
                : defaultPreRevealRendererId;

            if (preferredRendererId >= preRevealRendererCount) {
                preferredRendererId = defaultPreRevealRendererId;
            }

            string memory svgContent = _renderPreRevealSVG(preferredRendererId, ctx);
            // Convert to data URI
            image = string(abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svgContent))
            ));
            
            // Generate HTML countdown for animation_url
            string memory html = _renderPreRevealHtml(preferredRendererId, ctx);
            if (bytes(html).length > 0) {
                animationUrl = html;
            }
            
            description = hasWords
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
            
            description = hasWords
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
            name = hasWords
                ? wordsText
                : string(abi.encodePacked(
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
        uint256 tokenPoints = getPoints(tokenId);
        json = string(abi.encodePacked(
            json,
            ',"attributes":[',
            '{"trait_type":"Year","value":', revealYear.toString(), '},',
            '{"trait_type":"Queue Rank","value":', rank.toString(), '},',
            '{"trait_type":"Points","value":', tokenPoints.toString(), '}'
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
    
    function _renderPreRevealSVG(uint256 preferredRendererId, RenderTypes.RenderCtx memory ctx)
        internal
        view
        returns (string memory)
    {
        if (_rendererUsable(preferredRendererId)) {
            PreRevealRenderer storage renderer = preRevealRenderers[preferredRendererId];
            try renderer.svgRenderer.render(ctx) returns (string memory svg) {
                return svg;
            } catch {
                // continue to fallback
            }
        }

        if (preferredRendererId != defaultPreRevealRendererId) {
            require(_rendererUsable(defaultPreRevealRendererId), "Default pre-reveal renderer unavailable");
            PreRevealRenderer storage fallbackRenderer = preRevealRenderers[defaultPreRevealRendererId];
            try fallbackRenderer.svgRenderer.render(ctx) returns (string memory fallbackSvg) {
                return fallbackSvg;
            } catch {
                revert("Default pre-reveal renderer error");
            }
        }

        revert("Pre-reveal renderer error");
    }

    function _renderPreRevealHtml(uint256 preferredRendererId, RenderTypes.RenderCtx memory ctx)
        internal
        view
        returns (string memory)
    {
        (bool success, string memory html) = _tryRenderPreRevealHtml(preferredRendererId, ctx);
        if (success) {
            return html;
        }
        if (preferredRendererId != defaultPreRevealRendererId) {
            (bool fallbackSuccess, string memory fallbackHtml) = _tryRenderPreRevealHtml(defaultPreRevealRendererId, ctx);
            if (fallbackSuccess) {
                return fallbackHtml;
            }
        }
        return "";
    }

    function _tryRenderPreRevealHtml(uint256 rendererId, RenderTypes.RenderCtx memory ctx)
        internal
        view
        returns (bool, string memory)
    {
        if (rendererId >= preRevealRendererCount) {
            return (false, "");
        }
        PreRevealRenderer storage renderer = preRevealRenderers[rendererId];
        if (!renderer.active) {
            return (false, "");
        }
        ICountdownHtmlRenderer htmlRenderer = renderer.htmlRenderer;
        if (address(htmlRenderer) == address(0)) {
            return (false, "");
        }
        try htmlRenderer.render(ctx) returns (string memory html) {
            return (true, html);
        } catch {
            return (false, "");
        }
    }

    function _rendererUsable(uint256 rendererId) private view returns (bool) {
        if (rendererId >= preRevealRendererCount) {
            return false;
        }
        PreRevealRenderer storage renderer = preRevealRenderers[rendererId];
        return renderer.active && address(renderer.svgRenderer) != address(0);
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
    
}
