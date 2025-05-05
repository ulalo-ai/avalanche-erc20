// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IUlaloFaucet
 * @dev Interface for UlaloFaucet contract
 */
interface IUlaloFaucet {
    /**
     * @dev Returns the owner of the contract
     */
    function owner() external view returns (address);
    
    /**
     * @dev Returns the manager of the contract
     */
    function manager() external view returns (address);
    
    /**
     * @dev Returns the token address
     */
    function token() external view returns (address);
    
    /**
     * @dev Returns the faucet limit
     */
    function faucetLimit() external view returns (uint256);
    
    /**
     * @dev Returns the total amount sent
     */
    function totalSent() external view returns (uint256);
    
    /**
     * @dev Sets the token address
     */
    function setTokenAddress(address tokenAddress) external;
    
    /**
     * @dev Sets the faucet limit
     */
    function setFaucetLimit(uint256 newLimit) external;
    
    /**
     * @dev Withdraws tokens from the faucet
     */
    function drip(address to) external;
    
    /**
     * @dev Withdraws a specific amount of tokens from the faucet
     */
    function withdraw(uint256 amount, address to) external;

    /**
     * @dev Changes the manager of the faucet
     */
    function changeManager(address newManager) external;
    
    /**
     * @dev Returns the remaining limit
     */
    function getRemainingLimit() external view returns (uint256);
    
    /**
     * @dev Returns the contract balance
     */
    function getContractBalance() external view returns (uint256);
    
    /**
     * @dev Withdraws all tokens from the faucet
     */
    function withdrawAll(address to) external;
}