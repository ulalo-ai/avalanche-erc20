// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IUlaloToken
 * @dev Interface for UlaloToken with all required functions and events
 */
interface IUlaloToken is IERC20 {
    /**
     * @dev Emitted when the transfer limit percentage is updated
     */
    event TransferLimitUpdated(uint256 newLimit);
    
    /**
     * @dev Emitted when the cooldown period is updated
     */
    event CooldownUpdated(uint256 newCooldown);
    
    /**
     * @dev Emitted when an account's blacklist status is updated
     */
    event BlacklistUpdated(address indexed account, bool status);
    
    /**
     * @dev Emitted when a minter role is updated
     */
    event MinterUpdated(address indexed account, bool status);
    
    /**
     * @dev Emitted when a pauser role is updated
     */
    event PauserUpdated(address indexed account, bool status);
    
    /**
     * @dev Emitted when tokens are recovered from the contract
     */
    event TokenRecovered(address token, uint256 amount);

    /**
     * @dev Emitted when tokens are minted
     */
    event TokensMinted(address indexed minter, address indexed to, uint256 amount);

    /**
     * @dev Emitted when tokens are burned
     */
    event TokensBurned(address indexed burner, address indexed account, uint256 amount);
    /**
     * @dev Emitted when the contract is paused
     */
    event ContractPaused(address indexed pauser);
    /**
     * @dev Emitted when the contract is unpaused
     */
    event ContractUnpaused(address indexed pauser);
    
    /**
     * @dev Role identifiers
     */
    function MINTER_ROLE() external pure returns (bytes32);
    function BURNER_ROLE() external pure returns (bytes32);
    function PAUSER_ROLE() external pure returns (bytes32);
    function BLACKLISTER_ROLE() external pure returns (bytes32);
    
    /**
     * @dev Rate limiting parameters
     */
    function transferLimitPercentage() external view returns (uint256);
    function transferCooldown() external view returns (uint256);
    function lastTransferTime(address account) external view returns (uint256);
    
    /**
     * @dev Blacklist mapping
     */
    function blacklisted(address account) external view returns (bool);
    
    /**
     * @dev Creates `amount` new tokens for `to`.
     */
    function mint(address to, uint256 amount) external;
    
    /**
     * @dev Burns tokens from the caller's account.
     */
    function burn(uint256 amount) external;
    
    /**
     * @dev Burns tokens from a specific account.
     */
    function burnFrom(address account, uint256 amount) external;
    
    /**
     * @dev Pauses all token transfers.
     */
    function pause() external;
    
    /**
     * @dev Unpauses all token transfers.
     */
    function unpause() external;
    
    /**
     * @dev Sets the transfer limit as a percentage of total supply
     */
    function setTransferLimitPercentage(uint256 percentage) external;
    
    /**
     * @dev Sets the cooldown period for large transfers
     */
    function setTransferCooldown(uint256 cooldownPeriod) external;
    
    /**
     * @dev Adds or removes an address from the blacklist
     */
    function updateBlacklist(address account, bool shouldBlacklist) external;
    
    /**
     * @dev Grants a specific role to an account
     * @param role The role being granted
     * @param account The address receiving the role
     */
    function grantRoleTo(bytes32 role, address account) external;
    
    /**
     * @dev Revokes a specific role from an account
     * @param role The role being revoked
     * @param account The address losing the role
     */
    function revokeRoleFrom(bytes32 role, address account) external;
    
    /**
     * @dev Emergency token recovery function
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}