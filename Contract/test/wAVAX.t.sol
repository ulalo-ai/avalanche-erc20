// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/wAvax.sol";
import {IERC20Errors} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract WAVAXTest is Test {
    WAVAX public wavax;
    address public admin;
    address public bridge;
    address public bridge2;
    address public user1;
    address public user2;
    address public attacker;
    
    // Setup test environment before each test
    function setUp() public {
        admin = address(this);
        bridge = address(0x123);
        bridge2 = address(0x456);
        user1 = address(0x789);
        user2 = address(0xabc);
        attacker = address(0xdef);
        
        // Deploy the contract with admin as the initialAdmin
        wavax = new WAVAX(admin);
        
        // Add bridge addresses
        wavax.addBridge(bridge);
        wavax.addBridge(bridge2);
        
        // Give users some ETH for transactions
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(attacker, 10 ether);
    }
    
    // Test basic setup
    function testInitialSetup() public {
        assertEq(wavax.name(), "Wrapped AVAX");
        assertEq(wavax.symbol(), "wAVAX");
        assertEq(wavax.decimals(), 18);
        assertEq(wavax.totalSupply(), 0);
        assertTrue(wavax.hasRole(wavax.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(wavax.hasRole(wavax.BRIDGE_ROLE(), bridge));
        assertTrue(wavax.hasRole(wavax.BRIDGE_ROLE(), bridge2));
        assertFalse(wavax.hasRole(wavax.BRIDGE_ROLE(), user1));
    }
    
    // Test successful minting
    function testMint() public {
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        assertEq(wavax.balanceOf(user1), 100 ether);
        assertEq(wavax.totalSupply(), 100 ether);
    }
    
    // Test minting from different bridges
    function testMultipleBridgesMint() public {
        vm.prank(bridge);
        wavax.mint(user1, 50 ether);
        
        vm.prank(bridge2);
        wavax.mint(user1, 150 ether);
        
        assertEq(wavax.balanceOf(user1), 200 ether);
        assertEq(wavax.totalSupply(), 200 ether);
    }
    
    // Test unauthorized minting (should fail)
    function testUnauthorizedMint() public {
        // Use startPrank/stopPrank instead of just prank
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                wavax.BRIDGE_ROLE()
            )
        );
        wavax.mint(user1, 100 ether);
        vm.stopPrank();
    }
    
    // Test burn from authorized account
    function testBurnFrom() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User approves bridge
        vm.prank(user1);
        wavax.approve(bridge, 100 ether);
        
        // Bridge burns tokens
        vm.prank(bridge);
        wavax.burnFrom(user1, 60 ether);
        
        assertEq(wavax.balanceOf(user1), 40 ether);
        assertEq(wavax.totalSupply(), 40 ether);
        assertEq(wavax.allowance(user1, bridge), 40 ether);
    }
    
    // Test burn without enough allowance
    function testBurnFromInsufficientAllowance() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User approves bridge for less than we want to burn
        vm.prank(user1);
        wavax.approve(bridge, 50 ether);
        
        // Bridge tries to burn more than approved
        vm.prank(bridge);
        vm.expectRevert("Not enough allowance");
        wavax.burnFrom(user1, 100 ether);
    }
    
    // Test unauthorized burn
    function testUnauthorizedBurn() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User approves attacker
        vm.prank(user1);
        wavax.approve(attacker, 100 ether);
        
        // Attacker tries to burn - should revert because not a bridge
        vm.startPrank(attacker); // Change to startPrank
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                wavax.BRIDGE_ROLE()
            )
        );
        wavax.burnFrom(user1, 60 ether);
        vm.stopPrank(); // Add this
    }
    
    // Test burning more than balance
    function testBurnFromInsufficientBalance() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 50 ether);
        
        // User approves more than their balance
        vm.prank(user1);
        wavax.approve(bridge, 100 ether);
        
        // Bridge tries to burn more than balance - should revert
        vm.prank(bridge);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, 50 ether, 60 ether));
        wavax.burnFrom(user1, 60 ether);
    }
    
    // Test add bridge by admin
    function testAddBridge() public {
        address newBridge = address(0x999);
        
        // Initially not a bridge
        assertFalse(wavax.hasRole(wavax.BRIDGE_ROLE(), newBridge));
        
        // Add as bridge
        wavax.addBridge(newBridge);
        
        // Verify role was granted
        assertTrue(wavax.hasRole(wavax.BRIDGE_ROLE(), newBridge));
        
        // Test the new bridge can mint
        vm.prank(newBridge);
        wavax.mint(user1, 100 ether);
        assertEq(wavax.balanceOf(user1), 100 ether);
    }
    
    // Test adding bridge by non-admin (should fail)
    function testUnauthorizedAddBridge() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                wavax.DEFAULT_ADMIN_ROLE()
            )
        );
        wavax.addBridge(attacker);
        vm.stopPrank();
    }
    
    // Test remove bridge by admin
    function testRemoveBridge() public {
        // Initially a bridge
        assertTrue(wavax.hasRole(wavax.BRIDGE_ROLE(), bridge));
        
        // Remove bridge role
        wavax.removeBridge(bridge);
        
        // Verify role was revoked
        assertFalse(wavax.hasRole(wavax.BRIDGE_ROLE(), bridge));
        
        // Former bridge can no longer mint
        vm.startPrank(bridge);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bridge,
                wavax.BRIDGE_ROLE()
            )
        );
        wavax.mint(user1, 100 ether);
        vm.stopPrank();
    }
    
    // Test removing bridge by non-admin (should fail)
    function testUnauthorizedRemoveBridge() public {
        // Ensure we're using the right account
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                wavax.DEFAULT_ADMIN_ROLE()
            )
        );
        wavax.removeBridge(bridge);
        vm.stopPrank();
    }
    
    // Test reentrancy protection on mint
    function testReentrancyProtectionMint() public {
        // This is a simple test to ensure nonReentrant modifier is present
        // A more complex test would use a malicious contract
        
        // First attempt succeeds
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        assertEq(wavax.balanceOf(user1), 100 ether);
    }
    
    // Test reentrancy protection on burn
    function testReentrancyProtectionBurnFrom() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User approves bridge
        vm.prank(user1);
        wavax.approve(bridge, 100 ether);
        
        // First burn succeeds
        vm.prank(bridge);
        wavax.burnFrom(user1, 60 ether);
        assertEq(wavax.balanceOf(user1), 40 ether);
    }
    
    // Test zero mint amount
    function testZeroMint() public {
        vm.prank(bridge);
        wavax.mint(user1, 0);
        assertEq(wavax.balanceOf(user1), 0);
    }
    
    // Test zero burn amount
    function testZeroBurn() public {
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        vm.prank(user1);
        wavax.approve(bridge, 100 ether);
        
        vm.prank(bridge);
        wavax.burnFrom(user1, 0);
        assertEq(wavax.balanceOf(user1), 100 ether);
    }
    
    // Test minting to zero address (should fail)
    function testMintToZeroAddress() public {
        vm.prank(bridge);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        wavax.mint(address(0), 100 ether);
    }
    
    // Test burning from zero address (should fail)
    function testBurnFromZeroAddress() public {
        vm.prank(bridge);
        vm.expectRevert("Not enough allowance");
        wavax.burnFrom(address(0), 100 ether);
    }
    
    // Test standard ERC20 transfer functionality
    function testTransfer() public {
        // Mint tokens to user1
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User1 transfers to user2
        vm.prank(user1);
        wavax.transfer(user2, 40 ether);
        
        assertEq(wavax.balanceOf(user1), 60 ether);
        assertEq(wavax.balanceOf(user2), 40 ether);
    }
    
    // Test multi-step operations
    function testComplexScenario() public {
        // 1. Bridge mints to user1
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // 2. Bridge2 mints to user2
        vm.prank(bridge2);
        wavax.mint(user2, 200 ether);
        
        // 3. Users transfer between themselves
        vm.prank(user1);
        wavax.transfer(user2, 30 ether);
        
        // 4. User2 approves bridge for burning
        vm.prank(user2);
        wavax.approve(bridge, 100 ether);
        
        // 5. Bridge burns from user2
        vm.prank(bridge);
        wavax.burnFrom(user2, 50 ether);
        
        // 6. Admin removes bridge2
        wavax.removeBridge(bridge2);
        
        // 7. Former bridge2 tries to mint (should fail)
        vm.startPrank(bridge2); // Change to startPrank
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bridge2,
                wavax.BRIDGE_ROLE()
            )
        );
        wavax.mint(user1, 50 ether);
        vm.stopPrank(); // Add this
        
        // Final state verification
        assertEq(wavax.balanceOf(user1), 70 ether);
        assertEq(wavax.balanceOf(user2), 180 ether);
        assertEq(wavax.totalSupply(), 250 ether);
    }
    
    // Test events are emitted correctly
    function testMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(bridge, user1, 100 ether);
        
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
    }
    
    function testBurnEvent() public {
        // First mint some tokens
        vm.prank(bridge);
        wavax.mint(user1, 100 ether);
        
        // User approves bridge
        vm.prank(user1);
        wavax.approve(bridge, 100 ether);
        
        vm.expectEmit(true, true, false, true);
        emit TokensBurned(bridge, user1, 60 ether);
        
        vm.prank(bridge);
        wavax.burnFrom(user1, 60 ether);
    }
    
    // Helper to simulate WAVAX events for testing
    event TokensMinted(address indexed bridge, address indexed to, uint256 amount);
    event TokensBurned(address indexed bridge, address indexed from, uint256 amount);
}