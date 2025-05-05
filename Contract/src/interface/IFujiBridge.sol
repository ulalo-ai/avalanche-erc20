// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBridgeBase.sol";

/**
 * @title IFujiBridge
 * @dev Interface for Fuji (Avalanche) Bridge contract
 */
interface IFujiBridge is IBridgeBase {
    /**
     * @dev Emitted when tokens are released from the bridge
     */
    event TokensReleased(address indexed recipient, uint256 amount, bytes32 transactionId);
    
    /**
     * @dev Emitted when tokens are locked in the bridge
     */
    event TokensLocked(address indexed sender, uint256 amount, bytes32 transactionId);
    
    /**
     * @dev Releases tokens from the bridge
     */
    function releaseTokens(address recipient, uint256 amount, bytes32 transactionId) external;
    
    /**
     * @dev Locks tokens in the bridge
     */
    function lockTokens(uint256 amount, bytes32 ethereumAddress) external;
}