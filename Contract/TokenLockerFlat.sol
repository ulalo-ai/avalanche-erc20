// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/FujiCChainBridge.sol

/// ------------------------------
/// LOCK CONTRACT - Avalanche C-Chain (43113)
/// ------------------------------

contract TokenLocker {
    address public admin;
    mapping(address => bool) public supportedTokens;
    
    event TokenLocked(address indexed token, address indexed sender, uint256 amount, bytes32 indexed txId);
    event NativeCoinLocked(address indexed sender, uint256 amount, bytes32 indexed txId);
    event TokenUnlocked(address indexed token, address indexed recipient, uint256 amount);
    event NativeCoinUnlocked(address indexed recipient, uint256 amount);

    constructor() {
        admin = msg.sender;
    }

    // Token-specific functions
    function addSupportedToken(address token) external {
        require(msg.sender == admin, "Only admin");
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
    }

    function lockToken(address token, uint256 amount) external returns (bytes32) {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Invalid amount");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        bytes32 txId = keccak256(abi.encodePacked(msg.sender, token, amount, block.timestamp));
        emit TokenLocked(token, msg.sender, amount, txId);
        return txId;
    }

    function unlockToken(address token, address to, uint256 amount) external {
        require(msg.sender == admin, "Only admin");
        require(supportedTokens[token], "Token not supported");
        
        bool success = IERC20(token).transfer(to, amount);
        require(success, "Token transfer failed");
        
        emit TokenUnlocked(token, to, amount);
    }

    // Native coin-specific functions (no address parameter needed)
    function lockNativeCoin() external payable returns (bytes32) {
        uint256 amount = msg.value;
        require(amount > 0, "Invalid amount");

        bytes32 txId = keccak256(abi.encodePacked(msg.sender, amount, block.timestamp));
        emit NativeCoinLocked(msg.sender, amount, txId);
        return txId;
    }

    function unlockNativeCoin(address payable to, uint256 amount) external {
        require(msg.sender == admin, "Only admin");
        require(address(this).balance >= amount, "Insufficient native coin balance");
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Native coin transfer failed");
        
        emit NativeCoinUnlocked(to, amount);
    }

    // Access functions
    function isNativeCoinSupported() external pure returns (bool) {
        return true; // Native coin is always supported
    }

    // To receive native coins
    receive() external payable {}
}

