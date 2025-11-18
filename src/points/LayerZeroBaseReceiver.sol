// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import { ILayerZeroEndpointV2, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { ILayerZeroReceiver } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroReceiver.sol";
import "./PointsAggregator.sol";

/// @notice LayerZero receiver that relays Base checkpoints to the L1 PointsAggregator.
contract LayerZeroBaseReceiver is Ownable, ILayerZeroReceiver {
    ILayerZeroEndpointV2 public immutable endpoint;
    PointsAggregator public aggregator;

    mapping(uint32 => bytes32) public trustedPeers; // srcEid => remote collector address (in bytes32 form)

    event TrustedPeerSet(uint32 indexed srcEid, bytes32 peer);
    event CheckpointForwarded(uint32 indexed srcEid, bytes32 guid, address executor, uint256 payloadSize);
    event AggregatorUpdated(address newAggregator);

    error OnlyEndpoint(address caller);
    error InvalidPeer(uint32 srcEid, bytes32 sender);

    constructor(address _endpoint, address _aggregator) Ownable(msg.sender) {
        require(_endpoint != address(0), "Endpoint must be set");
        require(_aggregator != address(0), "Aggregator must be set");
        endpoint = ILayerZeroEndpointV2(_endpoint);
        aggregator = PointsAggregator(_aggregator);
        emit AggregatorUpdated(_aggregator);
    }

    /// @notice Configure the trusted LayerZero peer (the Base collector) for a given endpoint id.
    function setTrustedPeer(uint32 srcEid, bytes32 peer) external onlyOwner {
        trustedPeers[srcEid] = peer;
        emit TrustedPeerSet(srcEid, peer);
    }

    /// @notice Update the downstream PointsAggregator recipient.
    function setAggregator(address newAggregator) external onlyOwner {
        require(newAggregator != address(0), "Aggregator must be set");
        aggregator = PointsAggregator(newAggregator);
        emit AggregatorUpdated(newAggregator);
    }

    /// @notice Configure the LayerZero delegate (optional helper).
    function setEndpointDelegate(address delegate) external onlyOwner {
        endpoint.setDelegate(delegate);
    }

    /// @inheritdoc ILayerZeroReceiver
    function allowInitializePath(Origin calldata origin) external view override returns (bool) {
        return trustedPeers[origin.srcEid] == origin.sender;
    }

    /// @inheritdoc ILayerZeroReceiver
    function nextNonce(uint32, bytes32) external pure override returns (uint64) {
        return 0;
    }

    /// @inheritdoc ILayerZeroReceiver
    function lzReceive(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata /* extraData */
    ) external payable override {
        if (msg.sender != address(endpoint)) revert OnlyEndpoint(msg.sender);
        bytes32 peer = trustedPeers[origin.srcEid];
        if (peer == bytes32(0) || peer != origin.sender) revert InvalidPeer(origin.srcEid, origin.sender);

        aggregator.applyCheckpointFromBase(message);
        emit CheckpointForwarded(origin.srcEid, guid, executor, message.length);
    }

    /// @notice Allows the owner to sweep any stranded ETH.
    function sweep(address payable to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        if (balance == 0) {
            return;
        }
        (bool success, ) = to.call{value: balance}("");
        require(success, "Sweep failed");
    }

    receive() external payable {}
}
