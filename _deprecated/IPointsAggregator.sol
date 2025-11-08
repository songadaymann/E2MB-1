// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPointsAggregator {
    function applyCheckpointFromL1(bytes calldata payload) external;
}
