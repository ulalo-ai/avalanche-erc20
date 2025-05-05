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

// src/interface/IUlaloFaucet.sol

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

// src/UlaloFaucet.sol

contract UlaloTokenFaucet is IUlaloFaucet {
    address public override owner;
    address public override manager;
    IERC20 internal _token;
    uint256 public override faucetLimit;
    uint256 public override totalSent;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Not the manager");
        _;
    }

    constructor() {
        owner = msg.sender;
        manager = msg.sender;
    }

    function setTokenAddress(address tokenAddress) external override onlyManager {
        _token = IERC20(tokenAddress);
    }

    function token() external view override returns (address) {
        return address(_token);
    }

    function setFaucetLimit(uint256 newLimit) external override onlyManager {
        faucetLimit = newLimit;
    }

    function drip(address to) external {
        uint256 dripAmount = 1 ether; // 1 token per drip
        require(totalSent + dripAmount <= faucetLimit, "Faucet limit reached");
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= dripAmount, "Insufficient token balance");
        require(_token.transfer(to, dripAmount), "Token transfer failed");
        totalSent += dripAmount;
    }

    function changeManager(address newManager) external override onlyOwner {
        require(newManager != address(0), "Invalid address");
        manager = newManager;
    }

    // Helper view functions
    function getRemainingLimit() external view override returns (uint256) {
        return faucetLimit - totalSent;
    }

    function getContractBalance() public view override returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function withdraw(uint256 amount, address to) external override onlyManager {
        require(amount > 0, "Amount must be greater than zero");
        uint256 balance = getContractBalance();
        require(balance >= amount, "Insufficient contract balance");
        require(_token.transfer(to, amount), "Token transfer failed");
        totalSent += amount;
    }

    function withdrawAll(address to) external override onlyManager {
        uint256 balance = getContractBalance();
        require(balance > 0, "No tokens to withdraw");
        require(_token.transfer(to, balance), "Token transfer failed");
        totalSent += balance;
    }
    
    function depositTokens(uint256 amount) external {
        // Transfer tokens from sender to this contract
        require(_token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        // You could emit an event or do other accounting here
    }
    
    receive() external payable {
    }
}

