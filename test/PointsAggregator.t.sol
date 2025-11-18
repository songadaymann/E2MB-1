// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/points/PointsAggregator.sol";
import "../src/points/PointsManager.sol";
import "../src/interfaces/IRevealQueue.sol";

contract MockRevealQueue is IRevealQueue {
    uint256 public mintedCount;
    mapping(uint256 => bool) private _wordOverride;
    mapping(uint256 => bool) private _wordOverrideSet;

    constructor(uint256 minted_) {
        mintedCount = minted_;
    }

    function setMinted(uint256 minted_) external {
        mintedCount = minted_;
    }

    function setHasWords(uint256 tokenId, bool allowed) external {
        _wordOverride[tokenId] = allowed;
        _wordOverrideSet[tokenId] = true;
    }

    function basePermutation(uint256 tokenId) external pure returns (uint256) {
        return tokenId;
    }

    function totalMinted() external view returns (uint256) {
        return mintedCount;
    }

    function hasSevenWords(uint256 tokenId) external view returns (bool) {
        if (_wordOverrideSet[tokenId]) {
            return _wordOverride[tokenId];
        }
        return true;
    }
}

contract PointsAggregatorTest is Test {
    PointsManager private pointsManager;
    PointsAggregator private aggregator;
    MockRevealQueue private revealQueue;
    address private collector = address(this);

    function setUp() public {
        pointsManager = new PointsManager();
        aggregator = new PointsAggregator(address(pointsManager));
        pointsManager.setAggregator(address(aggregator));
        revealQueue = new MockRevealQueue(50);
        pointsManager.setRevealQueue(address(revealQueue));
        aggregator.setAuthorizedCollector(collector, true);
    }

    function testSkipsUnmintedToken() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory deltas = new uint256[](2);
        string[] memory sources = new string[](2);
        ids[0] = 1;
        ids[1] = 60;
        deltas[0] = 10;
        deltas[1] = 20;
        sources[0] = "BASE";
        sources[1] = "BAD";

        vm.expectEmit(true, true, true, true);
        emit PointsAggregator.CheckpointEntrySkipped(
            60,
            "BAD",
            20,
            PointsAggregator.SkipReason.TokenNotMinted
        );

        aggregator.applyCheckpointFromBase(abi.encode(ids, deltas, sources));

        assertEq(pointsManager.points(1), 10, "valid token not credited");
        assertEq(pointsManager.points(60), 0, "invalid token credited");
    }

    function testSkipsWhenPointsManagerRejects() public {
        revealQueue.setHasWords(2, false);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory deltas = new uint256[](2);
        string[] memory sources = new string[](2);
        ids[0] = 1;
        ids[1] = 2;
        deltas[0] = 5;
        deltas[1] = 5;
        sources[0] = "OK";
        sources[1] = "MISSING_WORDS";

        vm.expectEmit(true, true, true, true);
        emit PointsAggregator.CheckpointEntrySkipped(
            2,
            "MISSING_WORDS",
            5,
            PointsAggregator.SkipReason.PointsManagerRejected
        );

        aggregator.applyCheckpointFromBase(abi.encode(ids, deltas, sources));

        assertEq(pointsManager.points(1), 5);
        assertEq(pointsManager.points(2), 0);
    }

    function testSkipsZeroTokenId() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory deltas = new uint256[](2);
        string[] memory sources = new string[](2);
        ids[0] = 0;
        ids[1] = 3;
        deltas[0] = 9;
        deltas[1] = 7;
        sources[0] = "ZERO";
        sources[1] = "VALID";

        vm.expectEmit(true, true, true, true);
        emit PointsAggregator.CheckpointEntrySkipped(
            0,
            "ZERO",
            9,
            PointsAggregator.SkipReason.InvalidTokenId
        );

        aggregator.applyCheckpointFromBase(abi.encode(ids, deltas, sources));

        assertEq(pointsManager.points(3), 7);
    }

    function testEnforcesEntryLimitGracefully() public {
        aggregator.setCheckpointLimits(1, 1_000_000);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory deltas = new uint256[](2);
        string[] memory sources = new string[](2);
        ids[0] = 1;
        ids[1] = 4;
        deltas[0] = 2;
        deltas[1] = 3;
        sources[0] = "FIRST";
        sources[1] = "SECOND";

        vm.expectEmit(true, true, true, true);
        emit PointsAggregator.CheckpointEntrySkipped(
            4,
            "SECOND",
            3,
            PointsAggregator.SkipReason.TooManyEntries
        );

        aggregator.applyCheckpointFromBase(abi.encode(ids, deltas, sources));

        assertEq(pointsManager.points(1), 2);
        assertEq(pointsManager.points(4), 0);
    }
}
