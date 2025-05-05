// ETHEREUM MAINNET CONTRACT
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IEthereumBridge.sol";

contract EthereumBridge is Ownable, IEthereumBridge {
    IERC20 internal _token;
    address public tokenAddress;
    address public override validator;
    mapping(bytes32 => bool) public override processedTransactions;
    
    constructor(address initialOwner, address _tokenAddress, address validatorAddress) 
        Ownable(initialOwner) 
    {
        tokenAddress = _tokenAddress;  // Use different parameter name
        _token = IERC20(_tokenAddress);
        validator = validatorAddress;
    }
    
    function updateValidator(address _validator) external override onlyOwner {
        validator = _validator;
    }
    
    function lockTokens(uint256 amount, bytes32 destinationAddress) external override {
        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(msg.sender, amount, destinationAddress, block.timestamp));
        
        // Ensure this transaction hasn't been processed before
        require(!processedTransactions[transactionId], "Transaction already processed");
        
        // Lock tokens in this contract
        require(_token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Mark transaction as processed
        processedTransactions[transactionId] = true;
        
        // Emit event for the validator to pick up
        emit TokensLocked(msg.sender, amount, transactionId);
    }
    
    function burnTokens(uint256 amount, bytes32 destinationAddress) external override {
        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(msg.sender, amount, destinationAddress, block.timestamp));
        
        // Ensure this transaction hasn't been processed before
        require(!processedTransactions[transactionId], "Transaction already processed");
        
        // Transfer tokens from sender to this contract then "burn" them
        require(_token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Mark transaction as processed
        processedTransactions[transactionId] = true;
        
        // Emit event for the validator to pick up
        emit TokensBurned(msg.sender, amount, transactionId);
    }
    
    // Function for withdrawing tokens (for lock/mint model)
    function withdrawTokens(address to, uint256 amount) external override {
        require(msg.sender == validator, "Only validator can withdraw");
        require(_token.transfer(to, amount), "Token transfer failed");
    }

    function token() external view override returns (address) {
        return address(_token);
    }
}
