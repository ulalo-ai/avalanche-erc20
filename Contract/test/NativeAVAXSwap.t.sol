// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/UlaloSwap.sol";
import "./mocks/MockERC20.sol";

contract NativeAVAXSwapTest is Test {
    UlaloSwap public swapContract;
    MockERC20 public ulaloToken;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant INITIAL_LIQUIDITY_AVAX = 100 ether;  // 100 AVAX
    uint256 public constant INITIAL_LIQUIDITY_ULALO = 10000 ether; // 10,000 ULALO
    uint256 public constant TEST_AMOUNT = 10 ether; 
    
    function setUp() public {
        // Setup accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Fund test accounts with AVAX
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        
        // Deploy ULALO token
        ulaloToken = new MockERC20("Ulao Token", "ULALO", 18);
        
        // Mint tokens to users
        ulaloToken.mint(user1, 10000 ether);
        ulaloToken.mint(user2, 10000 ether);
        
        // Deploy UlaoSwap with native AVAX support
        swapContract = new UlaloSwap(address(ulaloToken), owner);
        
        // Add initial liquidity as owner
        ulaloToken.mint(address(this), INITIAL_LIQUIDITY_ULALO);
        ulaloToken.approve(address(swapContract), INITIAL_LIQUIDITY_ULALO);
        
        // Add liquidity with native AVAX
        swapContract.addLiquidityWithAVAX{value: INITIAL_LIQUIDITY_AVAX}(INITIAL_LIQUIDITY_ULALO);
        
        console2.log("Initial liquidity added - AVAX:", swapContract.reserve_AVAX(), "ULALO:", swapContract.reserve_Ulalo());
        console2.log("Swap contract AVAX balance:", address(swapContract).balance);
    }
    
    function test_swapAVAXForUlalo() public {
        vm.startPrank(user1);
        
        uint256 initialUlaloBalance = ulaloToken.balanceOf(user1);
        uint256 initialAVAXBalance = user1.balance;
        
        // Calculate expected Ulao amount
        uint256 amountIn = 5 ether; // 5 AVAX
        uint256 amountInWithFee = amountIn * 997 / 1000;
        uint256 expectedUlao = (INITIAL_LIQUIDITY_ULALO * amountInWithFee) / (INITIAL_LIQUIDITY_AVAX + amountInWithFee);
        
        // Allow some slippage (95% of expected)
        uint256 minAmountOut = expectedUlao * 95 / 100;
        
        // Swap AVAX for ULALO
        swapContract.swapAVAXForUlalo{value: amountIn}(minAmountOut);
        
        // Check balances
        uint256 finalUlaloBalance = ulaloToken.balanceOf(user1);
        uint256 finalAVAXBalance = user1.balance;
        
        console2.log("AVAX spent:", initialAVAXBalance - finalAVAXBalance);
        console2.log("ULALO received:", finalUlaloBalance - initialUlaloBalance);
        
        // Verify
        assertEq(finalAVAXBalance, initialAVAXBalance - amountIn, "Incorrect AVAX balance");
        assertEq(finalUlaloBalance, initialUlaloBalance + expectedUlao, "Incorrect ULALO balance");
        
        vm.stopPrank();
    }
    
    function test_SwapUlaoForAVAX() public {
        vm.startPrank(user2);
        
        uint256 initialUlaloBalance = ulaloToken.balanceOf(user2);
        uint256 initialAVAXBalance = user2.balance;
        
        // Calculate expected AVAX amount
        uint256 amountIn = 500 ether; // 500 ULALO
        uint256 amountInWithFee = amountIn * 997 / 1000;
        uint256 expectedAVAX = (INITIAL_LIQUIDITY_AVAX * amountInWithFee) / (INITIAL_LIQUIDITY_ULALO + amountInWithFee);
        
        // Allow some slippage (95% of expected)
        uint256 minAmountOut = expectedAVAX * 95 / 100;
        
        // Approve and swap ULALO for AVAX
        ulaloToken.approve(address(swapContract), amountIn);
        swapContract.swapUlaloForAVAX(amountIn, minAmountOut);
        
        // Check balances
        uint256 finalUlaloBalance = ulaloToken.balanceOf(user2);
        uint256 finalAVAXBalance = user2.balance;
        
        console2.log("ULALO spent:", initialUlaloBalance - finalUlaloBalance);
        console2.log("AVAX received:", finalAVAXBalance - initialAVAXBalance);
        
        // Verify
        assertEq(finalUlaloBalance, initialUlaloBalance - amountIn, "Incorrect ULALO balance");
        assertEq(finalAVAXBalance, initialAVAXBalance + expectedAVAX, "Incorrect AVAX balance");
        
        vm.stopPrank();
    }
    
    function test_AddRemoveLiquidity() public {
        vm.startPrank(user1);
        
        uint256 addAvax = 10 ether;
        uint256 addUlao = 1000 ether;
        
        // Approve Ulao tokens
        ulaloToken.approve(address(swapContract), addUlao);
        
        // Add liquidity
        uint256 initialLiquidity = swapContract.liquidityBalances(user1);
        swapContract.addLiquidityWithAVAX{value: addAvax}(addUlao);
        uint256 newLiquidity = swapContract.liquidityBalances(user1);
        uint256 liquidityAdded = newLiquidity - initialLiquidity;
        
        console2.log("Liquidity added:", liquidityAdded);
        
        // Remove half of the liquidity
        uint256 removeAmount = liquidityAdded / 2;
        
        uint256 initialUlaloBalance = ulaloToken.balanceOf(user1);
        uint256 initialAVAXBalance = user1.balance;
        
        swapContract.removeLiquidity(removeAmount);
        
        uint256 finalUlaloBalance = ulaloToken.balanceOf(user1);
        uint256 finalAVAXBalance = user1.balance;
        
        console2.log("AVAX returned:", finalAVAXBalance - initialAVAXBalance);
        console2.log("ULALO returned:", finalUlaloBalance - initialUlaloBalance);
        
        // Verify liquidity was removed
        assertEq(swapContract.liquidityBalances(user1), newLiquidity - removeAmount, "Incorrect liquidity balance");
        
        vm.stopPrank();
    }
}