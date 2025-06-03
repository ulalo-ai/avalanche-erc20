// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/IUlaloWrappedTokenMinter.sol";

interface IUlaloWrappedToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/// ------------------------------
/// MINT CONTRACT - Ulalo Network (237776)
/// ------------------------------
contract UlaloWrappedTokenMinter {
    address public admin;
    mapping(address => address) public originalToWrapped;
    mapping(bytes32 => bool) public processedTx;
    
    // The wrapped token to use for native coin (e.g., wAVAX)
    address public nativeCoinWrapped;

    event TokenMinted(address indexed wrappedToken, address indexed to, uint256 amount, bytes32 indexed srcTxId);
    event WrappedBurned(address indexed wrappedToken, address indexed from, uint256 amount, bytes32 indexed burnId);
    event NativeCoinWrappedMinted(address indexed to, uint256 amount, bytes32 indexed srcTxId);
    event NativeCoinWrappedBurned(address indexed from, uint256 amount, bytes32 indexed burnId);

    constructor() {
        admin = msg.sender;
    }

    function addWrappedToken(address originalToken, address wrappedToken) external {
        require(msg.sender == admin, "Only admin");
        require(originalToken != address(0), "Invalid original token address");
        require(wrappedToken != address(0), "Invalid wrapped token address");
        originalToWrapped[originalToken] = wrappedToken;
    }

    function setNativeCoinWrapped(address wrappedToken) external {
        require(msg.sender == admin, "Only admin");
        require(wrappedToken != address(0), "Invalid token address");
        nativeCoinWrapped = wrappedToken;
    }

    // For ERC20 tokens
    function mintWrapped(address originalToken, address to, uint256 amount, bytes32 srcTxId) external {
        require(msg.sender == admin, "Only admin");
        require(!processedTx[srcTxId], "Already processed");
        address wrappedToken = originalToWrapped[originalToken];
        require(wrappedToken != address(0), "Unsupported token");

        processedTx[srcTxId] = true;
        IUlaloWrappedToken(wrappedToken).mint(to, amount);
        emit TokenMinted(wrappedToken, to, amount, srcTxId);
    }

    // For native coin
    function mintNativeCoinWrapped(address to, uint256 amount, bytes32 srcTxId) external {
        require(msg.sender == admin, "Only admin");
        require(!processedTx[srcTxId], "Already processed");
        require(nativeCoinWrapped != address(0), "Native coin wrapped token not set");

        processedTx[srcTxId] = true;
        IUlaloWrappedToken(nativeCoinWrapped).mint(to, amount);
        emit NativeCoinWrappedMinted(to, amount, srcTxId);
    }

    // For ERC20 tokens
    function burnWrapped(address wrappedToken, uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(wrappedToken != nativeCoinWrapped, "Use burnNativeCoinWrapped for native coin");
        
        IUlaloWrappedToken(wrappedToken).burnFrom(msg.sender, amount);
        bytes32 burnId = keccak256(abi.encodePacked(msg.sender, wrappedToken, amount, block.timestamp));
        emit WrappedBurned(wrappedToken, msg.sender, amount, burnId);
    }
    
    // For native coin
    function burnNativeCoinWrapped(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(nativeCoinWrapped != address(0), "Native coin wrapped token not set");
        
        IUlaloWrappedToken(nativeCoinWrapped).burnFrom(msg.sender, amount);
        bytes32 burnId = keccak256(abi.encodePacked(msg.sender, "NATIVE", amount, block.timestamp));
        emit NativeCoinWrappedBurned(msg.sender, amount, burnId);
    }
    
    // Helper function to check if a token is supported
    function isWrappedTokenSupported(address originalToken) external view returns (bool) {
        return originalToWrapped[originalToken] != address(0);
    }
    
    // Helper function to get the wrapped token for an original token
    function getWrappedToken(address originalToken) external view returns (address) {
        return originalToWrapped[originalToken];
    }
    
    // Helper function to check if native coin wrapping is supported
    function isNativeCoinWrappingSupported() external view returns (bool) {
        return nativeCoinWrapped != address(0);
    }
}
