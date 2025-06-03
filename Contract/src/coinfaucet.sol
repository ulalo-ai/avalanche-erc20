// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICoinFaucet {
    function owner() external view returns (address);
    function manager() external view returns (address);
    function faucetLimit() external view returns (uint256);
    function totalSent() external view returns (uint256);
    function setFaucetLimit(uint256 newLimit) external;
    function drip(address to) external;
    function changeManager(address newManager) external;
    function getRemainingLimit() external view returns (uint256);
    function getContractBalance() external view returns (uint256);
    function withdraw(uint256 amount, address payable to) external;
    function withdrawAll(address payable to) external;
}

contract CoinFaucet is ICoinFaucet {
    address public override owner;
    address public override manager;
    uint256 public override faucetLimit;
    uint256 public override totalSent;
    uint256 public dripAmount = 0.05 ether; // Default drip amount (0.05 native coins)

    event FaucetFunded(address indexed funder, uint256 amount);
    event DripSent(address indexed recipient, uint256 amount);
    event FaucetWithdrawal(address indexed to, uint256 amount);

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

    function setFaucetLimit(uint256 newLimit) external override onlyManager {
        faucetLimit = newLimit;
    }

    function setDripAmount(uint256 newAmount) external onlyManager {
        require(newAmount > 0, "Drip amount must be greater than 0");
        dripAmount = newAmount;
    }

    function drip(address to) external override {
        require(totalSent + dripAmount <= faucetLimit, "Faucet limit reached");
        uint256 balance = address(this).balance;
        require(balance >= dripAmount, "Insufficient balance");
        
        (bool success, ) = payable(to).call{value: dripAmount}("");
        require(success, "Transfer failed");
        
        totalSent += dripAmount;
        emit DripSent(to, dripAmount);
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
        return address(this).balance;
    }

    function withdraw(uint256 amount, address payable to) external override onlyManager {
        require(amount > 0, "Amount must be greater than zero");
        uint256 balance = address(this).balance;
        require(balance >= amount, "Insufficient contract balance");
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
        
        totalSent += amount;
        emit FaucetWithdrawal(to, amount);
    }

    function withdrawAll(address payable to) external override onlyManager {
        uint256 balance = address(this).balance;
        require(balance > 0, "No coins to withdraw");
        
        (bool success, ) = to.call{value: balance}("");
        require(success, "Transfer failed");
        
        totalSent += balance;
        emit FaucetWithdrawal(to, balance);
    }
    
    // Receive function to accept native coins
    receive() external payable {
        // This function is called when someone sends coins to the contract
        emit FaucetFunded(msg.sender, msg.value);
    }
    
    // Fallback function
    fallback() external payable {
        emit FaucetFunded(msg.sender, msg.value);
    }
}