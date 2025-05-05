// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interface/IUlaloToken.sol";

/**
 * @title UlaloToken
 * @dev Implementation of the UlaloToken with advanced security features
 */
contract UlaloToken is ERC20, ReentrancyGuard, AccessControl, Pausable, IUlaloToken {
    using Math for uint256;

    // Define roles
    bytes32 public constant override MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant override BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant override PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant override BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    
    // Rate limiting parameters
    uint256 public override transferLimitPercentage = 1; // Default 1% of total supply
    uint256 public override transferCooldown = 1 hours;
    mapping(address => uint256) public override lastTransferTime;
    
    // Blacklist mapping
    mapping(address => bool) public override blacklisted;

    constructor(string memory name, string memory symbol, address initialOwner) 
        ERC20(name, symbol)
    {
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(BURNER_ROLE, initialOwner);
        _grantRole(PAUSER_ROLE, initialOwner);
        _grantRole(BLACKLISTER_ROLE, initialOwner);
        
        // Initialize with a fixed supply for the owner
        _mint(initialOwner, 100000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public override nonReentrant {
        require(hasRole(MINTER_ROLE, _msgSender()), "UlaloToken: must have minter role to mint");
        _mint(to, amount);
    }
    
    function burn(uint256 amount) public virtual override nonReentrant {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual override nonReentrant {
        if (_msgSender() != account) {
            require(
                hasRole(BURNER_ROLE, _msgSender()),
                "UlaloToken: must have burner role to burn from another account"
            );
        }
        _burn(account, amount);
        emit TokensBurned(_msgSender(), account, amount);
    }
    
    function pause() public override {
        require(hasRole(PAUSER_ROLE, _msgSender()), "UlaloToken: must have pauser role to pause");
        _pause();
    }

    function unpause() public override {
        require(hasRole(PAUSER_ROLE, _msgSender()), "UlaloToken: must have pauser role to unpause");
        _unpause();
    }
    
    function setTransferLimitPercentage(uint256 percentage) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(percentage <= 100, "UlaloToken: percentage must be between 0 and 100");
        transferLimitPercentage = percentage;
        emit TransferLimitUpdated(percentage);
    }
    
    function setTransferCooldown(uint256 cooldownPeriod) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        transferCooldown = cooldownPeriod;
        emit CooldownUpdated(cooldownPeriod);
    }
    
    function updateBlacklist(address account, bool shouldBlacklist) external override onlyRole(BLACKLISTER_ROLE) {
        blacklisted[account] = shouldBlacklist;
        emit BlacklistUpdated(account, shouldBlacklist);
    }
    
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure we're not trying to recover this token
        require(tokenAddress != address(this), "UlaloToken: Cannot recover the token itself");
        
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit TokenRecovered(tokenAddress, tokenAmount);
    }

    function _checkRateLimit(address from, uint256 amount) internal view returns (bool) {
        // Skip rate limiting for whitelisted roles
        if (hasRole(MINTER_ROLE, from) || hasRole(DEFAULT_ADMIN_ROLE, from)) {
            return true;
        }
        
        if (transferLimitPercentage == 0) return true; // No limit if set to 0
        
        uint256 maxTransferAmount = totalSupply() * transferLimitPercentage / 100;
        return amount <= maxTransferAmount;
    }
    
    function _checkCooldown(address from) internal view returns (bool) {
        // Skip cooldown for whitelisted roles
        if (hasRole(MINTER_ROLE, from) || hasRole(DEFAULT_ADMIN_ROLE, from)) {
            return true;
        }
        
        if (transferCooldown == 0) return true; // No cooldown if set to 0
        
        return (block.timestamp >= lastTransferTime[from] + transferCooldown);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused nonReentrant {
        require(!blacklisted[from], "UlaloToken: sender is blacklisted");
        require(!blacklisted[to], "UlaloToken: recipient is blacklisted");
        
        // Skip checks for minting and burning
        if (from != address(0) && to != address(0)) {
            // Check rate limiting
            require(_checkRateLimit(from, amount), "UlaloToken: transfer exceeds rate limit");
            
            // Check cooldown period
            require(_checkCooldown(from), "UlaloToken: cooldown period not yet elapsed");
            
            // Update last transfer time
            lastTransferTime[from] = block.timestamp;
        }
        
        // Call parent implementation
        super._update(from, to, amount);
    }
}