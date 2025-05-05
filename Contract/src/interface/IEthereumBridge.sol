// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBridgeBase.sol";

/**
 * @title IEthereumBridge
 * @dev Interface for Ethereum Bridge contract
 */
interface IEthereumBridge is IBridgeBase {
    /**
     * @dev Emitted when tokens are locked in the bridge
     */
    event TokensLocked(address indexed sender, uint256 amount, bytes32 transactionId);
    
    /**
     * @dev Emitted when tokens are burned
     */
    event TokensBurned(address indexed sender, uint256 amount, bytes32 transactionId);
    
    /**
     * @dev Locks tokens in the bridge
     */
    function lockTokens(uint256 amount, bytes32 destinationAddress) external;
    
    /**
     * @dev Burns tokens through the bridge
     */
    function burnTokens(uint256 amount, bytes32 destinationAddress) external;
}