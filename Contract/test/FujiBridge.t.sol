// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/FujiBridge.sol";
import "./mocks/MockERC20.sol";

contract FujiBridgeTest is Test {
    FujiBridge public bridge;
    MockERC20 public token;
    
    address public owner;
    address public validator;
    address public user1;
    address public user2;
    
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant TEST_AMOUNT = 1000 ether;
    
    function setUp() public {
        // Setup accounts
        owner = address(this);
        validator = makeAddr("validator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        console2.log("Test setup - Owner:", owner);
        console2.log("Test setup - Validator:", validator);
        console2.log("Test setup - User1:", user1);
        console2.log("Test setup - User2:", user2);
        
        // Deploy token
        token = new MockERC20("Fuji Test Token", "FTT", 18);
        console2.log("Test token deployed at:", address(token));
        
        // Mint tokens to bridge and users
        token.mint(address(this), INITIAL_SUPPLY);
        token.mint(user1, INITIAL_SUPPLY);
        token.mint(user2, INITIAL_SUPPLY);
        
        // Deploy bridge
        bridge = new FujiBridge(owner, address(token), validator);
        console2.log("FujiBridge deployed at:", address(bridge));
        
        // Fund the bridge with tokens for releases
        token.transfer(address(bridge), INITIAL_SUPPLY / 2);
        console2.log("Funded bridge with:", INITIAL_SUPPLY / 2);
    }
    
    function test_InitialState() public {
        console2.log("==== Testing Initial State ====");
        console2.log("Bridge owner:", bridge.owner());
        console2.log("Bridge token:", address(bridge.token()));
        console2.log("Bridge validator:", bridge.validator());
        console2.log("Bridge token balance:", token.balanceOf(address(bridge)));
        
        assertEq(bridge.owner(), owner);
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.validator(), validator);
        assertEq(token.balanceOf(address(bridge)), INITIAL_SUPPLY / 2);
    }
    
    function test_UpdateValidator() public {
        console2.log("==== Testing Update Validator ====");
        address newValidator = makeAddr("newValidator");
        console2.log("Current validator:", bridge.validator());
        console2.log("New validator:", newValidator);
        
        bridge.updateValidator(newValidator);
        console2.log("Validator after update:", bridge.validator());
        
        assertEq(bridge.validator(), newValidator);
    }
    
    function testFail_UpdateValidatorNotOwner() public {
        console2.log("==== Testing Update Validator Not Owner (should fail) ====");
        address newValidator = makeAddr("newValidator");
        console2.log("Current validator:", bridge.validator());
        console2.log("Attempting to update validator from non-owner:", user1);
        
        vm.prank(user1);
        bridge.updateValidator(newValidator);
    }
    
    function test_ReleaseTokens() public {
        console2.log("==== Testing Release Tokens ====");
        
        // Create a fake transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked("test_tx_id"));
        console2.log("Transaction ID:", uint256(transactionId));
        
        // Check initial balances
        uint256 initialBalance = token.balanceOf(user1);
        uint256 initialBridgeBalance = token.balanceOf(address(bridge));
        console2.log("Initial balance of user1:", initialBalance);
        console2.log("Initial balance of bridge:", initialBridgeBalance);
        
        // Expect the TokensReleased event
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(user1, TEST_AMOUNT, transactionId);
        
        // Release tokens as validator
        console2.log("Releasing", TEST_AMOUNT, "tokens to user1 as validator");
        vm.prank(validator);
        bridge.releaseTokens(user1, TEST_AMOUNT, transactionId);
        
        // Verify balance after
        uint256 finalBalance = token.balanceOf(user1);
        uint256 finalBridgeBalance = token.balanceOf(address(bridge));
        console2.log("Final balance of user1:", finalBalance);
        console2.log("Final balance of bridge:", finalBridgeBalance);
        console2.log("Balance change - user1:", int256(finalBalance) - int256(initialBalance));
        console2.log("Balance change - bridge:", int256(finalBridgeBalance) - int256(initialBridgeBalance));
        
        assertEq(finalBalance, initialBalance + TEST_AMOUNT);
        assertEq(finalBridgeBalance, initialBridgeBalance - TEST_AMOUNT);
        
        // Verify transaction is marked as processed
        bool isProcessed = bridge.processedTransactions(transactionId);
        console2.log("Transaction processed:", isProcessed);
        assertTrue(isProcessed);
    }
    
    function testFail_ReleaseTokensNotValidator() public {
        console2.log("==== Testing Release Tokens Not Validator (should fail) ====");
        
        bytes32 transactionId = keccak256(abi.encodePacked("test_tx_id"));
        console2.log("Transaction ID:", uint256(transactionId));
        
        console2.log("Attempting to release tokens as non-validator:", user1);
        
        // Try to release as non-validator (should fail)
        vm.prank(user1);
        bridge.releaseTokens(user2, TEST_AMOUNT, transactionId);
    }
    
    function testFail_ReleaseTokensTwice() public {
        console2.log("==== Testing Release Tokens Twice (should fail) ====");
        
        bytes32 transactionId = keccak256(abi.encodePacked("test_tx_id"));
        console2.log("Transaction ID (same for both attempts):", uint256(transactionId));
        
        // Release first time
        console2.log("First release attempt");
        vm.prank(validator);
        bridge.releaseTokens(user1, TEST_AMOUNT, transactionId);
        
        console2.log("User1 balance after first release:", token.balanceOf(user1));
        
        // Try to release again with same transaction ID (should fail)
        console2.log("Second release attempt with same transaction ID (should fail)");
        vm.prank(validator);
        bridge.releaseTokens(user1, TEST_AMOUNT, transactionId);
    }
    
    function test_LockTokens() public {
        console2.log("==== Testing Lock Tokens ====");
        
        // Generate ethereum destination address
        bytes32 ethereumAddress = bytes32(uint256(uint160(user2)));
        console2.log("Ethereum destination address:", uint256(ethereumAddress));
        
        vm.startPrank(user1);
        
        // Approve bridge to spend tokens
        token.approve(address(bridge), TEST_AMOUNT);
        console2.log("Approved bridge to spend:", TEST_AMOUNT);
        
        // Get balances before
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 bridgeBalanceBefore = token.balanceOf(address(bridge));
        console2.log("Initial balances - User1:", user1BalanceBefore, "Bridge:", bridgeBalanceBefore);
        
        // Expect the TokensLocked event
        vm.expectEmit(true, false, false, true);
        bytes32 expectedTxId = keccak256(abi.encodePacked(user1, TEST_AMOUNT, ethereumAddress, block.timestamp));
        console2.log("Expected transaction ID:", uint256(expectedTxId));
        emit TokensLocked(user1, TEST_AMOUNT, expectedTxId);
        
        // Lock tokens
        bridge.lockTokens(TEST_AMOUNT, ethereumAddress);
        console2.log("Tokens locked");
        
        // Get balances after
        uint256 user1BalanceAfter = token.balanceOf(user1);
        uint256 bridgeBalanceAfter = token.balanceOf(address(bridge));
        console2.log("Final balances - User1:", user1BalanceAfter, "Bridge:", bridgeBalanceAfter);
        console2.log("Change in balances - User1:", int256(user1BalanceAfter) - int256(user1BalanceBefore)); 
        console2.log("Bridge:", int256(bridgeBalanceAfter) - int256(bridgeBalanceBefore));
        
        // Verify balances
        assertEq(user1BalanceAfter, user1BalanceBefore - TEST_AMOUNT);
        assertEq(bridgeBalanceAfter, bridgeBalanceBefore + TEST_AMOUNT);
        
        // Verify transaction is marked as processed
        bool isProcessed = bridge.processedTransactions(expectedTxId);
        console2.log("Transaction processed:", isProcessed);
        assertTrue(isProcessed);
        
        vm.stopPrank();
    }
    
    function test_WithdrawTokensAsValidator() public {
        console2.log("==== Testing Withdraw Tokens As Validator ====");
        
        // Check balances before withdrawal
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 bridgeBalanceBefore = token.balanceOf(address(bridge));
        console2.log("Initial balances - User2:", user2BalanceBefore, "Bridge:", bridgeBalanceBefore);
        
        // Withdraw tokens as validator
        console2.log("Withdrawing as validator:", validator);
        vm.prank(validator);
        bridge.withdrawTokens(user2, TEST_AMOUNT);
        
        // Check balances after withdrawal
        uint256 user2BalanceAfter = token.balanceOf(user2);
        uint256 bridgeBalanceAfter = token.balanceOf(address(bridge));
        console2.log("Final balances - User2:", user2BalanceAfter, "Bridge:", bridgeBalanceAfter);
        console2.log("Change in balances - User2:", int256(user2BalanceAfter) - int256(user2BalanceBefore)); 
        console2.log("Bridge:", int256(bridgeBalanceAfter) - int256(bridgeBalanceBefore));
        
        // Verify balances
        assertEq(user2BalanceAfter, user2BalanceBefore + TEST_AMOUNT);
        assertEq(bridgeBalanceAfter, bridgeBalanceBefore - TEST_AMOUNT);
    }
    
    function testFail_WithdrawTokensNotValidator() public {
        console2.log("==== Testing Withdraw Tokens Not Validator (should fail) ====");
        
        // Try to withdraw tokens as non-validator (should fail)
        vm.prank(user1);
        bridge.withdrawTokens(user2, TEST_AMOUNT);
    }
    
    // Event definitions for testing
    event TokensReleased(address indexed recipient, uint256 amount, bytes32 transactionId);
    event TokensLocked(address indexed sender, uint256 amount, bytes32 transactionId);
}