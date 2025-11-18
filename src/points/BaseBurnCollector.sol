// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ILayerZeroEndpointV2, MessagingFee, MessagingParams, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "../../lib/bokkypon/BokkyPooBahsDateTimeLibrary.sol";

contract BaseBurnCollector is Ownable, ERC1155Holder {
    using SafeERC20 for IERC20;
    struct PendingDelta {
        uint256 tokenId;
        uint256 amount;
        string source;
    }

    mapping(address => uint256) public eligibleAssets; // baseValue per asset
    address[] private eligibleAssetList;
    mapping(address => bool) private isEligibleAssetListed;
    mapping(address => uint8) public assetDecimals; // ERC20 normalization

    mapping(uint256 => PendingDelta[]) private pending; // tokenId => pending deltas (reset on checkpoint)

    ILayerZeroEndpointV2 public immutable endpoint;
    address public l1Aggregator;
    bytes32 public l1AggregatorPeer;
    uint32 public l1EndpointId;
    bytes public checkpointOptions;

    uint256[12] public monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    uint256 public maxTokensPerCheckpoint = 100;
    uint256 public maxDeltaPerToken = 1_000_000;

    event BurnQueued(
        address indexed burner,
        address asset,
        uint256 tokenIdOrAmount,
        uint256 pointsEarned,
        uint256 month,
        string source
    );
    event CheckpointQueued(uint256 tokenId, uint256 points, string source);
    event CheckpointSent(
        uint256 tokenCount,
        uint256 totalPoints,
        bytes payload,
        bytes32 guid,
        uint64 nonce,
        uint256 nativeFee
    );
    event LayerZeroConfigured(address endpoint, uint32 dstEid, bytes32 peer, bytes options);
    event CheckpointLimitsUpdated(uint256 maxTokensPerCheckpoint, uint256 maxDeltaPerToken);

    error LayerZeroNotConfigured();
    error IncorrectMsgValue(uint256 required, uint256 provided);
    error EmptyCheckpoint();
    error NoPendingPoints();
    error CheckpointTokenLimitExceeded(uint256 requested, uint256 limit);
    error CheckpointDeltaTooLarge(uint256 tokenId, uint256 delta, uint256 limit);

    constructor(
        address _endpoint,
        address _l1Aggregator,
        uint32 _l1EndpointId,
        bytes memory _checkpointOptions
    ) Ownable(msg.sender) {
        require(_endpoint != address(0), "Endpoint must be set");
        require(_l1Aggregator != address(0), "Aggregator must be set");
        endpoint = ILayerZeroEndpointV2(_endpoint);
        l1Aggregator = _l1Aggregator;
        l1AggregatorPeer = _addressToBytes32(_l1Aggregator);
        l1EndpointId = _l1EndpointId;
        checkpointOptions = _checkpointOptions.length == 0 ? _defaultCheckpointOptions() : _checkpointOptions;
        emit LayerZeroConfigured(_endpoint, _l1EndpointId, l1AggregatorPeer, checkpointOptions);
    }

    function setAggregator(address newAggregator) external onlyOwner {
        require(newAggregator != address(0), "Aggregator must be set");
        l1Aggregator = newAggregator;
        l1AggregatorPeer = _addressToBytes32(newAggregator);
        emit LayerZeroConfigured(address(endpoint), l1EndpointId, l1AggregatorPeer, checkpointOptions);
    }

    function setAggregatorPeer(bytes32 newPeer) external onlyOwner {
        l1AggregatorPeer = newPeer;
        emit LayerZeroConfigured(address(endpoint), l1EndpointId, newPeer, checkpointOptions);
    }

    function setL1EndpointId(uint32 newEid) external onlyOwner {
        l1EndpointId = newEid;
        emit LayerZeroConfigured(address(endpoint), newEid, l1AggregatorPeer, checkpointOptions);
    }

    function setCheckpointOptions(bytes calldata newOptions) external onlyOwner {
        checkpointOptions = newOptions.length == 0 ? _defaultCheckpointOptions() : newOptions;
        emit LayerZeroConfigured(address(endpoint), l1EndpointId, l1AggregatorPeer, checkpointOptions);
    }

    function setCheckpointLimits(uint256 maxTokens, uint256 maxDelta) external onlyOwner {
        require(maxTokens > 0, "Max tokens must be > 0");
        require(maxDelta > 0, "Max delta must be > 0");
        maxTokensPerCheckpoint = maxTokens;
        maxDeltaPerToken = maxDelta;
        emit CheckpointLimitsUpdated(maxTokens, maxDelta);
    }

    function addEligibleAsset(address asset, uint256 baseValue) external onlyOwner {
        _setEligibleAsset(asset, baseValue, 0);
    }

    function addEligibleAssetWithDecimals(address asset, uint256 baseValue, uint8 decimalsHint) external onlyOwner {
        _setEligibleAsset(asset, baseValue, decimalsHint);
    }

    function _setEligibleAsset(address asset, uint256 baseValue, uint8 decimalsHint) internal {
        require(baseValue > 0, "Base must be > 0");
        if (!isEligibleAssetListed[asset]) {
            eligibleAssetList.push(asset);
            isEligibleAssetListed[asset] = true;
        }
        eligibleAssets[asset] = baseValue;
        assetDecimals[asset] = decimalsHint;
    }

    function setMonthWeights(uint256[12] calldata weights) external onlyOwner {
        monthWeights = weights;
    }

    function queueERC721(address asset, uint256 tokenId, uint256 msongTokenId) external {
        require(eligibleAssets[asset] > 0, "Asset not eligible");
        IERC721(asset).transferFrom(msg.sender, address(this), tokenId);
        uint256 points = calculatePoints(asset, 1, msg.sender);
        pending[msongTokenId].push(PendingDelta(msongTokenId, points, "BASE_ERC721"));
        emit BurnQueued(msg.sender, asset, tokenId, points, getMonth(), "BASE_ERC721");
    }

    function queueERC1155(address asset, uint256 id, uint256 amount, uint256 msongTokenId) external {
        require(eligibleAssets[asset] > 0, "Asset not eligible");
        IERC1155(asset).safeTransferFrom(msg.sender, address(this), id, amount, "");
        uint256 points = calculatePoints(asset, amount, msg.sender);
        pending[msongTokenId].push(PendingDelta(msongTokenId, points, "BASE_ERC1155"));
        emit BurnQueued(msg.sender, asset, amount, points, getMonth(), "BASE_ERC1155");
    }

    function queueERC20(address asset, uint256 amount, uint256 msongTokenId) external {
        require(eligibleAssets[asset] > 0, "Asset not eligible");
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        uint256 normalized = _normalizeMultiplier(asset, amount);
        uint256 points = calculatePoints(asset, normalized, msg.sender);
        pending[msongTokenId].push(PendingDelta(msongTokenId, points, "BASE_ERC20"));
        emit BurnQueued(msg.sender, asset, amount, points, getMonth(), "BASE_ERC20");
    }

    function quoteCheckpoint(uint256[] calldata tokenIds) external view returns (MessagingFee memory fee) {
        if (l1EndpointId == 0 || l1AggregatorPeer == bytes32(0)) revert LayerZeroNotConfigured();
        uint256 length = tokenIds.length;
        if (length == 0) revert EmptyCheckpoint();
        if (length > maxTokensPerCheckpoint) revert CheckpointTokenLimitExceeded(length, maxTokensPerCheckpoint);
        uint256 entryCount;
        uint256[] memory ids = new uint256[](length);
        uint256[] memory deltas = new uint256[](length);
        string[] memory sources = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            PendingDelta[] storage items = pending[tokenIds[i]];
            uint256 aggregate;
            string memory source = "";
            for (uint256 j = 0; j < items.length; j++) {
                aggregate += items[j].amount;
                source = items[j].source;
            }
            if (aggregate > maxDeltaPerToken) {
                revert CheckpointDeltaTooLarge(tokenIds[i], aggregate, maxDeltaPerToken);
            }
            ids[i] = tokenIds[i];
            deltas[i] = aggregate;
            sources[i] = source;
            entryCount += items.length;
        }

        if (entryCount == 0) revert NoPendingPoints();

        bytes memory payload = abi.encode(ids, deltas, sources);
        MessagingParams memory params = MessagingParams({
            dstEid: l1EndpointId,
            receiver: l1AggregatorPeer,
            message: payload,
            options: checkpointOptions,
            payInLzToken: false
        });

        return endpoint.quote(params, address(this));
    }

    function checkpoint(
        uint256[] calldata tokenIds
    ) external payable returns (MessagingReceipt memory receipt) {
        if (l1EndpointId == 0 || l1AggregatorPeer == bytes32(0)) revert LayerZeroNotConfigured();
        uint256 length = tokenIds.length;
        if (length == 0) revert EmptyCheckpoint();
        if (length > maxTokensPerCheckpoint) revert CheckpointTokenLimitExceeded(length, maxTokensPerCheckpoint);
        uint256 totalPoints;
        uint256 entryCount;
        uint256[] memory ids = new uint256[](length);
        uint256[] memory deltas = new uint256[](length);
        string[] memory sources = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            PendingDelta[] storage items = pending[tokenIds[i]];
            uint256 aggregate;
            string memory source = "";
            for (uint256 j = 0; j < items.length; j++) {
                aggregate += items[j].amount;
                source = items[j].source;
            }
            if (aggregate > maxDeltaPerToken) {
                revert CheckpointDeltaTooLarge(tokenIds[i], aggregate, maxDeltaPerToken);
            }
            ids[i] = tokenIds[i];
            deltas[i] = aggregate;
            sources[i] = source;
            totalPoints += aggregate;
            entryCount += items.length;
            delete pending[tokenIds[i]];
            emit CheckpointQueued(tokenIds[i], aggregate, source);
        }

        if (entryCount == 0) revert NoPendingPoints();

        bytes memory payload = abi.encode(ids, deltas, sources);
        MessagingParams memory params = MessagingParams({
            dstEid: l1EndpointId,
            receiver: l1AggregatorPeer,
            message: payload,
            options: checkpointOptions,
            payInLzToken: false
        });

        MessagingFee memory fee = endpoint.quote(params, address(this));
        if (msg.value < fee.nativeFee) revert IncorrectMsgValue(fee.nativeFee, msg.value);

        receipt = endpoint.send{value: fee.nativeFee}(params, msg.sender);
        uint256 refund = msg.value - fee.nativeFee;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "Refund failed");
        }
        emit CheckpointSent(entryCount, totalPoints, payload, receipt.guid, receipt.nonce, fee.nativeFee);
    }

    function calculatePoints(address asset, uint256 multiplier, address burner) internal view returns (uint256) {
        uint256 month = getMonth();
        return eligibleAssets[asset] * multiplier * monthWeights[month] / 100 / 100;
    }

    function getMonth() internal view returns (uint256) {
        (, uint256 month, ) = DateTime.timestampToDate(block.timestamp);
        return month - 1;
    }

    function _normalizeMultiplier(address asset, uint256 multiplier) internal view returns (uint256) {
        uint8 decimalsHint = assetDecimals[asset];
        if (decimalsHint == 0) {
            return multiplier;
        }
        return multiplier / (10 ** decimalsHint);
    }

    function _defaultCheckpointOptions() internal pure returns (bytes memory) {
        // Legacy options type 1: 16 bits type identifier, followed by 128-bit gas limit (padded to 256 bits)
        return abi.encodePacked(uint16(1), uint256(300_000));
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
