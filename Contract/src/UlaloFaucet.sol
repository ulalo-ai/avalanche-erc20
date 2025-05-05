// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IUlaloFaucet.sol";

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
