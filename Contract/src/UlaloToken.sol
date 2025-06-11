// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    using SafeERC20 for IERC20;
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

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address Minter,
        address Burner,
        address Pauser,
        address Blacklister
    ) ERC20(name, symbol) {
        require(initialOwner != address(0), "UlaloToken: initial owner cannot be zero address");
        require(Minter != address(0), "UlaloToken: minter cannot be zero address");
        require(Burner != address(0), "UlaloToken: burner cannot be zero address");
        require(Pauser != address(0), "UlaloToken: pauser cannot be zero address");
        require(Blacklister != address(0), "UlaloToken: blacklister cannot be zero address");

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, Minter);
        _grantRole(BURNER_ROLE, Burner);
        _grantRole(PAUSER_ROLE, Pauser);
        _grantRole(BLACKLISTER_ROLE, Blacklister);
        
        // Initialize supply
        uint256 initialSupply = 100000000 * 10**decimals();
        _mint(initialOwner, initialSupply);

        emit TokensMinted(address(this), initialOwner, initialSupply);
    }
    
    function mint(address to, uint256 amount) public override nonReentrant whenNotPaused {
        require(to != address(0), "UlaloToken: mint to the zero address");
        require(amount > 0, "UlaloToken: mint amount must be greater than zero");
        require(hasRole(MINTER_ROLE, _msgSender()), "UlaloToken: must have minter role to mint");
        _mint(to, amount);
        emit TokensMinted(_msgSender(), to, amount);
    }
    
    function burn(uint256 amount) public virtual override nonReentrant whenNotPaused {
        require(
            hasRole(BURNER_ROLE, _msgSender()),
            "UlaloToken: must have burner role to burn"
        );
        _burn(msg.sender, amount);
        emit TokensBurned(_msgSender(), msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public virtual override nonReentrant whenNotPaused {
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
        require(!paused(), "UlaloToken: contract is already paused");
        _pause();
        emit ContractPaused(_msgSender());
    }

    function unpause() public override {
        require(hasRole(PAUSER_ROLE, _msgSender()), "UlaloToken: must have pauser role to unpause");
        require(paused(), "UlaloToken: contract is not paused");
        _unpause();
        emit ContractUnpaused(_msgSender());
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
    
    /**
     * @dev Grants a specific role to an account
     * @param role The role being granted (use constants like MINTER_ROLE)
     * @param account The address receiving the role
     */
    function grantRoleTo(bytes32 role, address account) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
        emit RoleGranted(role, account, _msgSender());
    }

    /**
     * @dev Revokes a specific role from an account
     * @param role The role being revoked
     * @param account The address losing the role
     */
    function revokeRoleFrom(bytes32 role, address account) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
        emit RoleRevoked(role, account, _msgSender());
    }
    
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure we're not trying to recover this token
        require(tokenAmount != 0, "UlaloToken: Cannot recover zero amount");
        require(tokenAddress != address(0), "UlaloToken: Cannot recover to zero address");
        require(tokenAddress != address(this), "UlaloToken: Cannot recover the token itself");
        
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount); // Use safeTransfer instead of transfer
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
        if (lastTransferTime[from] == 0) return true; // Allow first-ever transfer for an address
        
        return (block.timestamp >= lastTransferTime[from] + transferCooldown);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused{
        // Allow minting operations (from == address(0))
        if (from == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Allow burning operations if sender has BURNER_ROLE
        if (to == address(0)) {
            require(hasRole(BURNER_ROLE, _msgSender()), "UlaloToken: must have burner role to burn");
            super._update(from, to, amount);
            return;
        }

        // Standard transfer checks
        require(amount > 0, "UlaloToken: transfer amount must be greater than zero");
        require(!blacklisted[from], "UlaloToken: sender is blacklisted");
        require(!blacklisted[to], "UlaloToken: recipient is blacklisted");
        
        // Skip rate limit and cooldown checks for privileged roles
        if (!hasRole(MINTER_ROLE, from) && !hasRole(DEFAULT_ADMIN_ROLE, from)) {
            require(_checkRateLimit(from, amount), "UlaloToken: transfer exceeds rate limit");
            require(_checkCooldown(from), "UlaloToken: cooldown period not yet elapsed");
            lastTransferTime[from] = block.timestamp;
        }
        
        super._update(from, to, amount);
    }
}