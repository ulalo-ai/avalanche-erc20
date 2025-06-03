// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ------------------------------
/// LOCK CONTRACT - Avalanche C-Chain (43113)
/// ------------------------------
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


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
