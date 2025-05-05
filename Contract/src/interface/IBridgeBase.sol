// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBridgeBase
 * @dev Base interface for bridge contracts with common functionality
 */
interface IBridgeBase {
    /**
     * @dev Returns the token associated with the bridge
     */
    function token() external view returns (address);
    
    /**
     * @dev Returns the validator address
     */
    function validator() external view returns (address);
    
    /**
     * @dev Checks if a transaction has been processed
     */
    function processedTransactions(bytes32 txId) external view returns (bool);
    
    /**
     * @dev Updates the validator address
     */
    function updateValidator(address _validator) external;
    
    /**
     * @dev Withdraws tokens from the bridge
     */
    function withdrawTokens(address to, uint256 amount) external;
}