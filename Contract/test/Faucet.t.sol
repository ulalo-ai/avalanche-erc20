// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/UlaloFaucet.sol";
import "./mocks/MockERC20.sol";

contract UlaoTokenFaucetTest is Test {
    UlaloTokenFaucet public faucet;
    MockERC20 public mockToken;
    
    address public owner;
    address public manager;
    address public user1;
    address public user2;
    
    uint256 public constant INITIAL_SUPPLY = 1000000 ether; // 1 million tokens
    uint256 public constant FAUCET_LIMIT = 10000 ether;    // 10,000 tokens
    uint256 public constant DRIP_AMOUNT = 1 ether;         // 1 token per drip

    function setUp() public {
        // Setup accounts
        owner = address(this);
        manager = makeAddr("manager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        faucet = new UlaloTokenFaucet();
        mockToken = new MockERC20("Test Token", "TEST", 18);
        
        // Fund faucet with tokens
        mockToken.mint(address(faucet), INITIAL_SUPPLY);
        
        // Setup faucet parameters
        faucet.setTokenAddress(address(mockToken));
        faucet.setFaucetLimit(FAUCET_LIMIT);
    }

    function test_InitialState() public {
        assertEq(faucet.owner(), owner);
        assertEq(faucet.manager(), owner);
        assertEq(address(faucet.token()), address(mockToken));
        assertEq(faucet.faucetLimit(), FAUCET_LIMIT);
        assertEq(faucet.totalSent(), 0);
    }

    function test_ChangeManager() public {
        faucet.changeManager(manager);
        assertEq(faucet.manager(), manager);
    }

    function testFail_ChangeManagerByNonOwner() public {
        vm.prank(user1);
        faucet.changeManager(user2);
    }

    function testFail_ChangeManagerToZeroAddress() public {
        faucet.changeManager(address(0));
    }

    function test_SetFaucetLimit() public {
        uint256 newLimit = 20000 ether;
        faucet.setFaucetLimit(newLimit);
        assertEq(faucet.faucetLimit(), newLimit);
    }

    function testFail_SetFaucetLimitByNonManager() public {
        vm.prank(user1);
        faucet.setFaucetLimit(2000 ether);
    }

    function test_DripTokens() public {
        // Record balances before
        uint256 beforeBalance = mockToken.balanceOf(user1);
        uint256 beforeTotalSent = faucet.totalSent();
        
        // Drip tokens to user1
        faucet.drip(user1);
        
        // Check balances after
        assertEq(mockToken.balanceOf(user1), beforeBalance + DRIP_AMOUNT);
        assertEq(faucet.totalSent(), beforeTotalSent + DRIP_AMOUNT);
    }

    function testFail_ExceedingLimitDrip() public {
        // Set a very low limit
        faucet.setFaucetLimit(DRIP_AMOUNT - 1);
        
        // Try to drip tokens, should fail
        faucet.drip(user1);
    }

    function test_DripByAnyone() public {
        // Record starting balances
        uint256 beforeBalance = mockToken.balanceOf(user1);
        uint256 beforeTotalSent = faucet.totalSent();
        
        // Have a non-manager account drip tokens
        vm.prank(user2); // user2 is not a manager
        faucet.drip(user1);
        
        // Verify the balances changed correctly
        assertEq(mockToken.balanceOf(user1), beforeBalance + DRIP_AMOUNT, "User should receive tokens");
        assertEq(faucet.totalSent(), beforeTotalSent + DRIP_AMOUNT, "Total sent should increase");
    }

    function test_DripExceedingLimit() public {
        // Set faucet limit to just 2 drips
        uint256 smallerLimit = DRIP_AMOUNT * 2;
        faucet.setFaucetLimit(smallerLimit);
        
        // Have a user drip twice (should work)
        vm.startPrank(user1);
        faucet.drip(user1);
        faucet.drip(user2);
        
        // Third drip should fail (exceeds limit)
        vm.expectRevert("Faucet limit reached");
        faucet.drip(user1);
        
        vm.stopPrank();
    }

    function test_MultipleDrips() public {
        // Drip to multiple users
        faucet.drip(user1);
        faucet.drip(user2);
        
        assertEq(mockToken.balanceOf(user1), DRIP_AMOUNT);
        assertEq(mockToken.balanceOf(user2), DRIP_AMOUNT);
        assertEq(faucet.totalSent(), DRIP_AMOUNT * 2);
        assertEq(faucet.getRemainingLimit(), FAUCET_LIMIT - (DRIP_AMOUNT * 2));
    }

    function test_GetRemainingLimit() public {
        faucet.drip(user1);
        
        assertEq(faucet.getRemainingLimit(), FAUCET_LIMIT - DRIP_AMOUNT);
    }

    function test_GetContractBalance() public {
        assertEq(faucet.getContractBalance(), INITIAL_SUPPLY);
        
        faucet.drip(user1);
        
        assertEq(faucet.getContractBalance(), INITIAL_SUPPLY - DRIP_AMOUNT);
    }

    function test_WithdrawAll() public {
        uint256 initialBalance = faucet.getContractBalance();
        faucet.withdrawAll(user1);
        
        assertEq(mockToken.balanceOf(user1), initialBalance);
        assertEq(faucet.getContractBalance(), 0);
        assertEq(faucet.totalSent(), initialBalance);
    }

    function testFail_WithdrawAllByNonManager() public {
        vm.prank(user1);
        faucet.withdrawAll(user1);
    }

    function testFail_WithdrawAllWhenEmpty() public {
        // First withdraw all tokens
        faucet.withdrawAll(user1);
        
        // Try to withdraw again from empty faucet
        faucet.withdrawAll(user2);
    }

    function test_CanReceiveEther() public {
        // Initial balance should be 0
        assertEq(address(faucet).balance, 0);
        
        // Send 1 ETH to the contract
        uint256 sendAmount = 1 ether;
        vm.deal(user1, sendAmount);
        
        vm.prank(user1);
        (bool success, ) = address(faucet).call{value: sendAmount}("");
        
        // Check if transfer was successful
        assertTrue(success);
        
        // Check if contract balance increased correctly
        assertEq(address(faucet).balance, sendAmount);
        
        // Check that user1's balance is now 0
        assertEq(user1.balance, 0);
    }

    function test_CanReceiveEtherMultipleTimes() public {
        // Initial balance should be 0
        assertEq(address(faucet).balance, 0);
        
        // Send ETH multiple times from different users
        uint256 sendAmount1 = 0.5 ether;
        uint256 sendAmount2 = 1.5 ether;
        
        vm.deal(user1, sendAmount1);
        vm.deal(user2, sendAmount2);
        
        vm.prank(user1);
        (bool success1, ) = address(faucet).call{value: sendAmount1}("");
        assertTrue(success1);
        
        vm.prank(user2);
        (bool success2, ) = address(faucet).call{value: sendAmount2}("");
        assertTrue(success2);
        
        // Check if contract balance increased correctly
        assertEq(address(faucet).balance, sendAmount1 + sendAmount2);
    }

    function test_OnlyManagerCanSetTokenAddress() public {
        vm.startPrank(user1);
        vm.expectRevert("Not the manager");
        faucet.setTokenAddress(address(0x123));
        vm.stopPrank();
    }

    function test_OnlyManagerCanSetFaucetLimit() public {
        vm.startPrank(user1);
        vm.expectRevert("Not the manager");
        faucet.setFaucetLimit(1000 ether);
        vm.stopPrank();
    }

    function test_OnlyManagerCanWithdrawAll() public {
        vm.startPrank(user1);
        vm.expectRevert("Not the manager");
        faucet.withdrawAll(user1);
        vm.stopPrank();
    }

    function test_AnyoneCanDrip() public {
        // Record balances before
        uint256 beforeBalance = mockToken.balanceOf(user1);
        uint256 beforeTotalSent = faucet.totalSent();
        
        // Even non-manager can call drip
        vm.prank(user2);
        faucet.drip(user1);
        
        // Check balances after
        assertEq(mockToken.balanceOf(user1), beforeBalance + DRIP_AMOUNT);
        assertEq(faucet.totalSent(), beforeTotalSent + DRIP_AMOUNT);
    }

    function test_DripRespectsFaucetLimit() public {
        uint256 dripLimit = 5;
        uint256 limitAmount = DRIP_AMOUNT * dripLimit;
        faucet.setFaucetLimit(limitAmount);
        
        vm.startPrank(user1);
        
        // Should be able to drip exactly 5 times
        for (uint i = 0; i < dripLimit; i++) {
            faucet.drip(user1);
        }
        
        // 6th drip should fail
        vm.expectRevert("Faucet limit reached");
        faucet.drip(user1);
        
        vm.stopPrank();
    }

    function test_DripInsufficientBalance() public {
        // Create a new faucet with minimal balance
        UlaloTokenFaucet newFaucet = new UlaloTokenFaucet();
        MockERC20 lowBalanceToken = new MockERC20("Low Balance", "LOW", 18);
        
        // Set token but don't mint enough
        lowBalanceToken.mint(address(newFaucet), 0.5 ether); // Less than 1 drip
        newFaucet.setTokenAddress(address(lowBalanceToken));
        newFaucet.setFaucetLimit(1000 ether);
        
        // Try to drip - should fail due to insufficient balance
        vm.expectRevert("Insufficient token balance");
        newFaucet.drip(user1);
    }

    function test_WithdrawTokens() public {
        uint256 withdrawAmount = 100 ether;
        uint256 initialBalance = faucet.getContractBalance();
        uint256 initialUserBalance = mockToken.balanceOf(user1);
        uint256 initialTotalSent = faucet.totalSent();
        
        // Withdraw tokens as manager (owner is manager by default)
        faucet.withdraw(withdrawAmount, user1);
        
        // Verify balances after withdrawal
        assertEq(mockToken.balanceOf(user1), initialUserBalance + withdrawAmount, "User should receive tokens");
        assertEq(faucet.getContractBalance(), initialBalance - withdrawAmount, "Contract balance should decrease");
        assertEq(faucet.totalSent(), initialTotalSent + withdrawAmount, "Total sent should increase");
    }

    function testFail_WithdrawByNonManager() public {
        uint256 withdrawAmount = 100 ether;
        
        // Try to withdraw as non-manager
        vm.prank(user1);
        faucet.withdraw(withdrawAmount, user1);
    }

    function testFail_WithdrawZeroAmount() public {
        // Try to withdraw zero tokens
        faucet.withdraw(0, user1);
    }

    function testFail_WithdrawExceedingBalance() public {
        uint256 contractBalance = faucet.getContractBalance();
        uint256 excessiveAmount = contractBalance + 1 ether;
        
        // Try to withdraw more than the contract balance
        faucet.withdraw(excessiveAmount, user1);
    }

    function test_WithdrawWithNewManager() public {
        // Set a new manager
        faucet.changeManager(manager);
        
        uint256 withdrawAmount = 100 ether;
        uint256 initialBalance = faucet.getContractBalance();
        uint256 initialUserBalance = mockToken.balanceOf(user1);
        
        // Withdraw tokens as the new manager
        vm.prank(manager);
        faucet.withdraw(withdrawAmount, user1);
        
        // Verify balances after withdrawal
        assertEq(mockToken.balanceOf(user1), initialUserBalance + withdrawAmount, "User should receive tokens");
        assertEq(faucet.getContractBalance(), initialBalance - withdrawAmount, "Contract balance should decrease");
    }

    function test_WithdrawUpdatesRemainingLimit() public {
        uint256 withdrawAmount = 100 ether;
        uint256 initialRemainingLimit = faucet.getRemainingLimit();
        
        // Withdraw tokens
        faucet.withdraw(withdrawAmount, user1);
        
        // Verify that the remaining limit is unchanged (withdrawals shouldn't affect limit)
        // The total sent increases, so remaining limit decreases
        assertEq(faucet.getRemainingLimit(), initialRemainingLimit - withdrawAmount);
    }
}