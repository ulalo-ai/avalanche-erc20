// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IUlaloSwap
 * @dev Interface for UlaloSwap contract with all required functions and events
 */
interface IUlaloSwap {
    /**
     * @dev Emitted when liquidity is added to the pool
     */
    event LiquidityAdded(address indexed provider, uint amount_AVAX, uint amount_Ulalo, uint liquidity);
    
    /**
     * @dev Emitted when liquidity is removed from the pool
     */
    event LiquidityRemoved(address indexed provider, uint amount_AVAX, uint amount_Ulalo, uint liquidity);
    
    /**
     * @dev Emitted when a swap occurs
     */
    event Swapped(address indexed user, address inputToken, uint amountIn, address outputToken, uint amountOut);
    
    /**
     * @dev Emitted when strict balance check setting is updated
     */
    event StrictBalanceCheckUpdated(bool enabled);
    
    /**
     * @dev Emitted when AVAX transfer fails
     */
    event AVAXTransferFailed(address recipient, uint256 amount);

    /**
     * @dev Returns the address used to represent native AVAX
     */
    function NATIVE_AVAX() external pure returns (address);
    
    /**
     * @dev Returns the address of the Ulalo token
     */
    function token_Ulalo() external view returns (address);
    
    /**
     * @dev Returns the amount of AVAX in the reserves
     */
    function reserve_AVAX() external view returns (uint);
    
    /**
     * @dev Returns the amount of Ulalo in the reserves
     */
    function reserve_Ulalo() external view returns (uint);
    
    /**
     * @dev Returns the liquidity balance of an address
     */
    function liquidityBalances(address provider) external view returns (uint);
    
    /**
     * @dev Returns the total liquidity in the pool
     */
    function totalLiquidity() external view returns (uint);
    
    /**
     * @dev Returns whether strict balance check is enabled
     */
    function strictBalanceCheckEnabled() external view returns (bool);
    
    /**
     * @dev Adds liquidity to the pool with native AVAX
     */
    function addLiquidityWithAVAX(uint amount_Ulalo) external payable;
    
    /**
     * @dev Removes liquidity from the pool
     */
    function removeLiquidity(uint liquidityAmount) external returns (uint256 avaxAmount, uint256 ulaoAmount);
    
    /**
     * @dev Helper function to send AVAX
     */
    function sendAVAX(address to, uint256 amount) external;
    
    /**
     * @dev Swaps AVAX for Ulalo tokens
     */
    function swapAVAXForUlalo(uint minAmountOut) external payable;
    
    /**
     * @dev Swaps Ulalo tokens for AVAX
     */
    function swapUlaloForAVAX(uint amountIn, uint minAmountOut) external;
    
    /**
     * @dev Calculates the amount of AVAX to receive for a given amount of Ulalo
     */
    function getAVAXForUlalo(uint amountIn) external view returns (uint);
    
    /**
     * @dev Calculates the amount of Ulalo to receive for a given amount of AVAX
     */
    function getUlaloForAVAX(uint amountIn) external view returns (uint);
    
    /**
     * @dev Pauses the contract
     */
    function pause() external;
    
    /**
     * @dev Unpauses the contract
     */
    function unpause() external;
    
    /**
     * @dev Sets whether strict balance check is enabled
     */
    function setStrictBalanceCheck(bool _enabled) external;
    
    /**
     * @dev Square root function
     */
    function sqrt(uint input) external pure returns (uint result);
}