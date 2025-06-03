// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/UlaloSwap.sol";
import "./mocks/MockERC20.sol";

contract NativeAVAXSwapTest is Test {
    UlaloSwap public swapContract;
    MockERC20 public wavaxToken;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant INITIAL_LIQUIDITY_ULALO = 100000 ether;
    uint256 public constant INITIAL_LIQUIDITY_AVAX = 200000 ether;

    function setUp() public {
        // Setup accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund test accounts with ULA (native coin)
        vm.deal(owner, INITIAL_LIQUIDITY_ULALO * 10);
        vm.deal(user1, INITIAL_LIQUIDITY_ULALO);
        vm.deal(user2, INITIAL_LIQUIDITY_ULALO);

        // Deploy wAVAX token
        wavaxToken = new MockERC20("Wrapped AVAX", "wAVAX", 18);
        
        // Deploy swap contract with wAVAX support
        swapContract = new UlaloSwap(address(wavaxToken), owner);
        
        // Mint tokens for testing
        wavaxToken.mint(owner, INITIAL_LIQUIDITY_AVAX * 10);
        wavaxToken.mint(user1, INITIAL_LIQUIDITY_AVAX);
        wavaxToken.mint(user2, INITIAL_LIQUIDITY_AVAX);
        
        // Add initial liquidity with native ULA - FIXED: Changed from addLiquidityWithAVAX to addLiquidityWithWAVAX
        wavaxToken.approve(address(swapContract), INITIAL_LIQUIDITY_AVAX);
        swapContract.addLiquidityWithWAVAX{value: INITIAL_LIQUIDITY_ULALO}(INITIAL_LIQUIDITY_AVAX);
        
        console2.log("Initial setup complete - Reserves: ULA =", swapContract.reserveULA(), "wAVAX =", swapContract.reserveWAVAX());
    }

    // Other test functions would be fixed similarly
}
