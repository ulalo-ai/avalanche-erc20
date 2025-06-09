// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/coinfaucet.sol";

contract CoinFaucetTest is Test {
    CoinFaucet public faucet;
    address public owner;
    address public user1;
    address public user2;
    address public manager;

    uint256 public initialBalance = 10 ether;
    uint256 public faucetLimit = 5 ether;
    uint256 public dripAmount = 0.05 ether;

    event FaucetFunded(address indexed funder, uint256 amount);
    event DripSent(address indexed recipient, uint256 amount);
    event FaucetWithdrawal(address indexed to, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        manager = makeAddr("manager");

        // Deploy the faucet contract
        faucet = new CoinFaucet();

        // Fund the faucet with initial balance
        vm.deal(address(this), initialBalance);
        (bool success, ) = address(faucet).call{value: initialBalance}("");
        require(success, "Funding failed");

        // Set faucet limit
        faucet.setFaucetLimit(faucetLimit);
    }

    function testInitialState() public {
        assertEq(faucet.owner(), owner);
        assertEq(faucet.manager(), owner);
        assertEq(faucet.faucetLimit(), faucetLimit);
        assertEq(faucet.totalSent(), 0);
        assertEq(faucet.dripAmount(), dripAmount);
        assertEq(faucet.getContractBalance(), initialBalance);
    }

    function testChangeManager() public {
        faucet.changeManager(manager);
        assertEq(faucet.manager(), manager);
    }

    function testFailChangeManagerNonOwner() public {
        vm.prank(user1);
        faucet.changeManager(manager);
    }

    function testSetFaucetLimit() public {
        uint256 newLimit = 10 ether;
        faucet.setFaucetLimit(newLimit);
        assertEq(faucet.faucetLimit(), newLimit);
    }

    function testFailSetFaucetLimitNonManager() public {
        vm.prank(user1);
        faucet.setFaucetLimit(10 ether);
    }

    function testSetDripAmount() public {
        uint256 newDripAmount = 0.1 ether;
        faucet.setDripAmount(newDripAmount);
        assertEq(faucet.dripAmount(), newDripAmount);
    }

    function testFailSetDripAmountNonManager() public {
        vm.prank(user1);
        faucet.setDripAmount(0.1 ether);
    }

    function testFailSetDripAmountZero() public {
        faucet.setDripAmount(0);
    }

    function testDrip() public {
        uint256 userInitialBalance = user1.balance;
        
        vm.expectEmit(true, true, true, true);
        emit DripSent(user1, dripAmount);
        
        faucet.drip(user1);
        
        assertEq(user1.balance, userInitialBalance + dripAmount);
        assertEq(faucet.totalSent(), dripAmount);
        assertEq(faucet.getContractBalance(), initialBalance - dripAmount);
    }

    function testMultipleDrips() public {
        faucet.drip(user1);
        faucet.drip(user2);
        faucet.drip(user1);
        
        assertEq(user1.balance, dripAmount * 2);
        assertEq(user2.balance, dripAmount);
        assertEq(faucet.totalSent(), dripAmount * 3);
    }

    function testFailDripBeyondLimit() public {
        // Set a very low limit
        faucet.setFaucetLimit(dripAmount * 2);
        
        // First two drips should succeed
        faucet.drip(user1);
        faucet.drip(user2);
        
        // Third drip should fail due to limit
        faucet.drip(user1);
    }

    function testFailDripInsufficientBalance() public {
        // Withdraw almost all funds leaving less than dripAmount
        uint256 withdrawAmount = initialBalance - (dripAmount / 2);
        faucet.withdraw(withdrawAmount, payable(owner));
        
        // This should fail due to insufficient balance
        faucet.drip(user1);
    }

    function testWithdraw() public {
        uint256 ownerInitialBalance = owner.balance;
        uint256 withdrawAmount = 1 ether;
        
        vm.expectEmit(true, true, true, true);
        emit FaucetWithdrawal(owner, withdrawAmount);
        
        faucet.withdraw(withdrawAmount, payable(owner));
        
        assertEq(owner.balance, ownerInitialBalance + withdrawAmount);
        assertEq(faucet.getContractBalance(), initialBalance - withdrawAmount);
        assertEq(faucet.totalSent(), withdrawAmount);
    }

    function testFailWithdrawNonManager() public {
        vm.prank(user1);
        faucet.withdraw(1 ether, payable(user1));
    }

    function testFailWithdrawZeroAmount() public {
        faucet.withdraw(0, payable(owner));
    }

    function testFailWithdrawInsufficientBalance() public {
        faucet.withdraw(initialBalance + 1 ether, payable(owner));
    }

    function testWithdrawAll() public {
        uint256 ownerInitialBalance = owner.balance;
        
        vm.expectEmit(true, true, true, true);
        emit FaucetWithdrawal(owner, initialBalance);
        
        faucet.withdrawAll(payable(owner));
        
        assertEq(owner.balance, ownerInitialBalance + initialBalance);
        assertEq(faucet.getContractBalance(), 0);
        assertEq(faucet.totalSent(), initialBalance);
    }

    function testFailWithdrawAllNonManager() public {
        vm.prank(user1);
        faucet.withdrawAll(payable(user1));
    }

    function testFailWithdrawAllEmptyBalance() public {
        // First withdraw everything
        faucet.withdrawAll(payable(owner));
        
        // Then try to withdraw again
        faucet.withdrawAll(payable(owner));
    }

    function testGetRemainingLimit() public {
        assertEq(faucet.getRemainingLimit(), faucetLimit);
        
        faucet.drip(user1);
        
        assertEq(faucet.getRemainingLimit(), faucetLimit - dripAmount);
    }

    function testReceiveFunds() public {
        uint256 fundAmount = 2 ether;
        vm.deal(user1, fundAmount);
        
        vm.expectEmit(true, true, true, true);
        emit FaucetFunded(user1, fundAmount);
        
        vm.prank(user1);
        (bool success, ) = address(faucet).call{value: fundAmount}("");
        require(success, "Funding failed");
        
        assertEq(faucet.getContractBalance(), initialBalance + fundAmount);
    }

    function testFallbackFunds() public {
        uint256 fundAmount = 2 ether;
        vm.deal(user1, fundAmount);
        
        vm.expectEmit(true, true, true, true);
        emit FaucetFunded(user1, fundAmount);
        
        vm.prank(user1);
        (bool success, ) = address(faucet).call{value: fundAmount}(hex"12345678");
        require(success, "Funding failed");
        
        assertEq(faucet.getContractBalance(), initialBalance + fundAmount);
    }

    // Helper function to receive ETH
    receive() external payable {}
}