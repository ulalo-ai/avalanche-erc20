// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title wAVAX
 * @dev Simple wrapped AVAX token for Ulalo bridge
 */
contract WAVAX is ERC20, ReentrancyGuard, AccessControl {
    // Define roles
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    // Events
    event TokensMinted(address indexed bridge, address indexed to, uint256 amount);
    event TokensBurned(address indexed bridge, address indexed from, uint256 amount);

    /**
     * @dev Constructor sets up the token and assigns the admin role
     * @param initialAdmin The address that will have admin rights to grant the BRIDGE_ROLE
     */
    constructor(address initialAdmin) 
        ERC20("Wrapped AVAX", "wAVAX")
    {
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /**
     * @dev Mints tokens to a specified address - can only be called by addresses with BRIDGE_ROLE
     * @param to Address receiving the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external nonReentrant onlyRole(BRIDGE_ROLE) {
        _mint(to, amount);
        emit TokensMinted(_msgSender(), to, amount);
    }
    
    /**
     * @dev Burns tokens from another account - can only be called by addresses with BRIDGE_ROLE
     * @param account Address to burn tokens from (must have approved the bridge)
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external nonReentrant onlyRole(BRIDGE_ROLE) {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "Not enough allowance");
        
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
        
        emit TokensBurned(_msgSender(), account, amount);
    }
    
    /**
     * @dev Grants the BRIDGE_ROLE to an address - can only be called by admin
     * @param bridgeAddress Address that will receive bridge privileges
     */
    function addBridge(address bridgeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BRIDGE_ROLE, bridgeAddress);
    }
    
    /**
     * @dev Removes the BRIDGE_ROLE from an address - can only be called by admin
     * @param bridgeAddress Address that will lose bridge privileges
     */
    function removeBridge(address bridgeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BRIDGE_ROLE, bridgeAddress);
    }

    /**
     * @dev Override to add decimals of 18 to match AVAX
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}