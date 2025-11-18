// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PointsAggregator.sol";
import { BokkyPooBahsDateTimeLibrary as DateTime } from "../../lib/bokkypon/BokkyPooBahsDateTimeLibrary.sol";

interface IBurnableERC721 {
    function burn(uint256 tokenId) external;
}

interface IBurnableERC1155 {
    function burnSelf(uint256 id, uint256 amount) external;
}

interface IBurnableERC20 {
    function burn(uint256 amount) external;
}

contract L1BurnCollector is Ownable, ERC165, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;
    PointsAggregator public aggregator;
    mapping(address => uint256) public eligibleAssets; // baseValue per asset
    address[] private eligibleAssetList;
    mapping(address => bool) private isEligibleAssetListed;
    mapping(address => uint8) public assetDecimals; // 0 for NFTs, >0 for ERC20 normalization
    address public songADayCollection;
    uint256[12] public monthWeights = [100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60];
    uint256 public songADayLockPeriod = 7 days;
    mapping(address => uint256) public songADayEligibleAfter;

    event BurnRecorded(address indexed burner, address asset, uint256 tokenIdOrAmount, uint256 pointsEarned, uint256 month, string source);
    event SongADayCollectionUpdated(address indexed newCollection);
    event SongADayLockPeriodUpdated(uint256 newPeriod);

    constructor(address _aggregator, address _songADayCollection) Ownable(msg.sender) {
        aggregator = PointsAggregator(_aggregator);
        songADayCollection = _songADayCollection;
        emit SongADayCollectionUpdated(_songADayCollection);
    }

    function addEligibleAsset(address asset, uint256 baseValue) public onlyOwner {
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

    function setSongADayCollection(address newCollection) external onlyOwner {
        songADayCollection = newCollection;
        emit SongADayCollectionUpdated(newCollection);
    }

    function setSongADayLockPeriod(uint256 newPeriod) external onlyOwner {
        songADayLockPeriod = newPeriod;
        emit SongADayLockPeriodUpdated(newPeriod);
    }

    function registerSongADayHold() external {
        _ensureSongADayTracking(msg.sender);
        require(songADayEligibleAfter[msg.sender] != 0, "No Song-A-Day balance");
    }

    function getEligibleAssets() external view returns (address[] memory assets, uint256[] memory baseValues) {
        assets = new address[](eligibleAssetList.length);
        baseValues = new uint256[](eligibleAssetList.length);
        for (uint256 i = 0; i < eligibleAssetList.length; i++) {
            address asset = eligibleAssetList[i];
            assets[i] = asset;
            baseValues[i] = eligibleAssets[asset];
        }
    }

    function monthWeightsArray() external view returns (uint256[12] memory) {
        return monthWeights;
    }

    function estimatePoints(address asset, uint256 amount, address burner) external view returns (uint256) {
        uint256 baseValue = eligibleAssets[asset];
        require(baseValue > 0, "Asset not eligible");
        if (amount == 0) {
            return 0;
        }
        uint256 normalized = _normalizeMultiplier(asset, amount);
        return calculatePoints(baseValue, normalized, burner);
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
        uint256 scale = 10 ** decimalsHint;
        return multiplier / scale;
    }

    function calculatePoints(uint256 baseValue, uint256 multiplier, address burner) internal view returns (uint256) {
        uint256 month = getMonth();
        uint256 songMultiplier = getSongADayMultiplier(burner);
        return baseValue * multiplier * monthWeights[month] * songMultiplier / 10000 / 10000;
    }

    function getSongADayMultiplier(address burner) internal view returns (uint256) {
        if (burner == address(0)) {
            return 10000;
        }
        address collection = songADayCollection;
        if (collection == address(0) || collection.code.length == 0) {
            return 10000;
        }
        uint256 balance = _songADayBalance(burner);
        if (balance == 0) {
            return 10000;
        }
        uint256 eligibleTime = songADayEligibleAfter[burner];
        if (eligibleTime == 0 || block.timestamp < eligibleTime) {
            return 10000;
        }
        if (balance >= 100) return 40000;
        if (balance >= 50) return 30000;
        if (balance >= 10) return 20000;
        if (balance >= 1) return 11000;
        return 10000;
    }

    function _songADayBalance(address account) internal view returns (uint256 balance) {
        address collection = songADayCollection;
        if (collection == address(0) || collection.code.length == 0) {
            return 0;
        }
        try IERC721(collection).balanceOf(account) returns (uint256 bal) {
            return bal;
        } catch {
            return 0;
        }
    }

    function _ensureSongADayTracking(address burner) internal {
        address collection = songADayCollection;
        if (collection == address(0) || collection.code.length == 0) {
            return;
        }
        uint256 balance = _songADayBalance(burner);
        if (balance == 0) {
            if (songADayEligibleAfter[burner] != 0) {
                songADayEligibleAfter[burner] = 0;
            }
            return;
        }
        if (songADayEligibleAfter[burner] == 0) {
            songADayEligibleAfter[burner] = block.timestamp + songADayLockPeriod;
        }
    }

    // ERC721 burn
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        require(eligibleAssets[msg.sender] > 0, "Asset not eligible");
        uint256 msongTokenId = abi.decode(data, (uint256));
        _ensureSongADayTracking(from);
        uint256 points = calculatePoints(eligibleAssets[msg.sender], 1, from);
        // Try to burn the NFT; if not possible, hold in contract
        try IBurnableERC721(msg.sender).burn(tokenId) {} catch {
            // Hold if no burn function
        }
        checkpointPoints(msongTokenId, points, "ERC721 burn");
        emit BurnRecorded(from, msg.sender, tokenId, points, getMonth(), "ERC721");
        return IERC721Receiver.onERC721Received.selector;
    }

    // ERC1155 burn
    function burnERC1155(address asset, uint256 id, uint256 amount, uint256 msongTokenId) external {
    require(eligibleAssets[asset] > 0, "Asset not eligible");
    IERC1155(asset).safeTransferFrom(msg.sender, address(this), id, amount, abi.encode(msongTokenId));
    }

    // ERC721 burn (direct)
    function burnERC721(address asset, uint256 tokenId, uint256 msongTokenId) external {
    require(eligibleAssets[asset] > 0, "Asset not eligible");
    IERC721(asset).safeTransferFrom(msg.sender, address(this), tokenId, abi.encode(msongTokenId));
    }

    // ERC1155 receiver
    function onERC1155Received(address, address from, uint256 id, uint256 amount, bytes calldata data) external override returns (bytes4) {
        require(eligibleAssets[msg.sender] > 0, "Asset not eligible");
        uint256 msongTokenId = abi.decode(data, (uint256));
        _ensureSongADayTracking(from);
        uint256 points = calculatePoints(eligibleAssets[msg.sender], amount, from);
        // Try to burn; if not possible, hold
        try IBurnableERC1155(msg.sender).burnSelf(id, amount) {} catch {
            // Hold if no burn function
        }
        checkpointPoints(msongTokenId, points, "ERC1155 burn");
        emit BurnRecorded(from, msg.sender, amount, points, getMonth(), "ERC1155");
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    // ERC20 burn
    function burnERC20(address asset, uint256 amount, uint256 msongTokenId) external {
    require(eligibleAssets[asset] > 0, "Asset not eligible");
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    _ensureSongADayTracking(msg.sender);
    uint256 normalizedAmount = _normalizeMultiplier(asset, amount);
    uint256 points = calculatePoints(eligibleAssets[asset], normalizedAmount, msg.sender);
        // Try to burn; if not possible, hold
        try IBurnableERC20(asset).burn(amount) {} catch {
            // Hold if no burn function
        }
        checkpointPoints(msongTokenId, points, "ERC20 burn");
        emit BurnRecorded(msg.sender, asset, amount, points, getMonth(), "ERC20");
    }

    function checkpointPoints(uint256 tokenId, uint256 points, string memory source) internal {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory deltas = new uint256[](1);
        string[] memory sources = new string[](1);
        tokenIds[0] = tokenId;
        deltas[0] = points;
        sources[0] = source;
        aggregator.applyCheckpointFromBase(abi.encode(tokenIds, deltas, sources));
    }
}
