// AVALANCHE FUJI TESTNET CONTRACT
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IFujiBridge.sol";

contract FujiBridge is Ownable, IFujiBridge {
    IERC20 internal _token;
    address public override validator;
    mapping(bytes32 => bool) public override processedTransactions;
    
    constructor(address initialOwner, address _tokenAddress, address validatorAddress) 
        Ownable(initialOwner) 
    {
        _token = IERC20(_tokenAddress);
        validator = validatorAddress;
    }
    
    function token() external view override returns (address) {
        return address(_token);
    }

    function updateValidator(address _validator) external override onlyOwner {
        validator = _validator;
    }
    
    function releaseTokens(address recipient, uint256 amount, bytes32 transactionId) external override {
        // Ensure only the validator can release tokens
        require(msg.sender == validator, "Only validator can release tokens");
        
        // Ensure this transaction hasn't been processed before
        require(!processedTransactions[transactionId], "Transaction already processed");
        
        // Mark transaction as processed
        processedTransactions[transactionId] = true;
        
        // Release tokens from bridge contract to the recipient
        require(_token.transfer(recipient, amount), "Token transfer failed");
        
        // Emit event
        emit TokensReleased(recipient, amount, transactionId);
    }
    
    function lockTokens(uint256 amount, bytes32 ethereumAddress) external override {
        // Generate a unique transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(msg.sender, amount, ethereumAddress, block.timestamp));
        
        // Ensure this transaction hasn't been processed before
        require(!processedTransactions[transactionId], "Transaction already processed");
        
        // Lock tokens in this contract
        require(_token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Mark transaction as processed
        processedTransactions[transactionId] = true;
        
        // Emit event for the validator to pick up
        emit TokensLocked(msg.sender, amount, transactionId);
    }
    
    // Allow validator to withdraw tokens if needed
    function withdrawTokens(address to, uint256 amount) external override {
        require(msg.sender == validator, "Only validator can withdraw");
        require(_token.transfer(to, amount), "Token transfer failed");
    }
}