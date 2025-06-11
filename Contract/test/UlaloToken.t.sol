// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UlaloToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UlaloTokenTest is Test {
    // Add these event declarations at the top of your contract
    event TokensMinted(address indexed minter, address indexed to, uint256 amount);
    event TokensBurned(address indexed burner, address indexed from, uint256 amount);
    event ContractPaused(address indexed pauser);

    UlaloToken public ulaloToken;
    
    address public owner;
    address public user1;
    address public user2;
    address public minter;
    address public burner;
    address public pauser;
    address public blacklister;

    uint256 public initialSupply = 100000000 * 10**18; // 100M tokens with 18 decimals
    
    function setUp() public {
        // Setup addresses
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        pauser = makeAddr("pauser");
        blacklister = makeAddr("blacklister");

        // Deploy token with initial supply minted to owner
        ulaloToken = new UlaloToken(
            "Ulalo Token",
            "ULA",
            owner,        
            minter,
            burner,
            pauser,
            blacklister
        );

        // Initial token distribution
        vm.startPrank(owner);
        ulaloToken.transfer(user1, 1000 * 10**18);
        ulaloToken.transfer(user2, 1000 * 10**18);
        vm.stopPrank();
    }
    
    // ===== Basic Token Tests =====
    
    function test_InitialState() public {
        assertEq(ulaloToken.name(), "Ulalo Token");
        assertEq(ulaloToken.symbol(), "ULA");
        assertEq(ulaloToken.decimals(), 18);
        assertEq(ulaloToken.totalSupply(), initialSupply);
        assertEq(ulaloToken.balanceOf(owner), initialSupply - 2000 * 10**18);
        assertEq(ulaloToken.balanceOf(user1), 1000 * 10**18);
        assertEq(ulaloToken.balanceOf(user2), 1000 * 10**18);
    }
    
    function test_Transfer() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        uint256 initialUser1Balance = ulaloToken.balanceOf(user1);
        uint256 initialUser2Balance = ulaloToken.balanceOf(user2);
        
        vm.prank(user1);
        ulaloToken.transfer(user2, 100 * 10**18);
        
        assertEq(ulaloToken.balanceOf(user1), initialUser1Balance - 100 * 10**18);
        assertEq(ulaloToken.balanceOf(user2), initialUser2Balance + 100 * 10**18);
    }
    
    function test_Approve_TransferFrom() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        uint256 initialUser1Balance = ulaloToken.balanceOf(user1);
        uint256 initialUser2Balance = ulaloToken.balanceOf(user2);
        
        vm.prank(user1);
        ulaloToken.approve(user2, 100 * 10**18);
        assertEq(ulaloToken.allowance(user1, user2), 100 * 10**18);
        
        vm.prank(user2);
        ulaloToken.transferFrom(user1, user2, 100 * 10**18);
        
        assertEq(ulaloToken.balanceOf(user1), initialUser1Balance - 100 * 10**18);
        assertEq(ulaloToken.balanceOf(user2), initialUser2Balance + 100 * 10**18);
        assertEq(ulaloToken.allowance(user1, user2), 0);
    }
    
    // ===== Role-Based Tests =====
    
    function test_RolesAssignment() public {
        // Verify initial roles assigned in constructor
        assertTrue(ulaloToken.hasRole(ulaloToken.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(ulaloToken.hasRole(ulaloToken.MINTER_ROLE(), minter));
        assertTrue(ulaloToken.hasRole(ulaloToken.BURNER_ROLE(), burner));
        assertTrue(ulaloToken.hasRole(ulaloToken.PAUSER_ROLE(), pauser));
        assertTrue(ulaloToken.hasRole(ulaloToken.BLACKLISTER_ROLE(), blacklister));
        
        // Verify owner has admin but not other roles
        assertTrue(ulaloToken.hasRole(ulaloToken.DEFAULT_ADMIN_ROLE(), owner));
        assertFalse(ulaloToken.hasRole(ulaloToken.MINTER_ROLE(), owner));
        assertFalse(ulaloToken.hasRole(ulaloToken.BURNER_ROLE(), owner));
        assertFalse(ulaloToken.hasRole(ulaloToken.PAUSER_ROLE(), owner));
        assertFalse(ulaloToken.hasRole(ulaloToken.BLACKLISTER_ROLE(), owner));
    }
    
    function test_GrantAndRevokeRole() public {
        address newMinter = address(0x7);
        
        // Grant role
        ulaloToken.grantRoleTo(ulaloToken.MINTER_ROLE(), newMinter);
        assertTrue(ulaloToken.hasRole(ulaloToken.MINTER_ROLE(), newMinter));
        
        // Revoke role
        ulaloToken.revokeRoleFrom(ulaloToken.MINTER_ROLE(), newMinter);
        assertFalse(ulaloToken.hasRole(ulaloToken.MINTER_ROLE(), newMinter));
    }
    
    function testFail_UnauthorizedRoleGrant() public {
        address newMinter = address(0x7);
        
        // User1 is not an admin, so this should fail with access control error
        vm.prank(user1);
        vm.expectRevert(); // Just expect any revert without checking the specific error
        ulaloToken.grantRoleTo(ulaloToken.MINTER_ROLE(), newMinter);
    }
    
    // ===== Minting Tests =====
    
    function test_MintByMinter() public {
        _resetAllTokenState();
        uint256 currentSupply = ulaloToken.totalSupply(); // Changed from initialSupply
        uint256 mintAmount = 500 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit TokensMinted(minter, user1, mintAmount);
        
        vm.prank(minter);
        ulaloToken.mint(user1, mintAmount);
        
        assertEq(ulaloToken.totalSupply(), currentSupply + mintAmount);
    }
    
    function testFail_UnauthorizedMint() public {
        vm.prank(user1);
        ulaloToken.mint(user1, 500 * 10**18);
    }
    
    // ===== Burning Tests =====
    
    function test_BurnFromByBurner() public {
        _resetAllTokenState();
        uint256 initialSupply = ulaloToken.totalSupply();
        uint256 burnAmount = 200 * 10**18;
    
        // Separate approve and burn transactions
        vm.startPrank(user1);
        ulaloToken.approve(burner, burnAmount);
        vm.stopPrank();
    
        vm.expectEmit(true, true, false, true);
        emit TokensBurned(burner, user1, burnAmount);
    
        vm.prank(burner);
        ulaloToken.burnFrom(user1, burnAmount);
    
        assertEq(ulaloToken.totalSupply(), initialSupply - burnAmount);
    }
    
    function test_BurnOwnTokens() public {
        ulaloToken.setTransferCooldown(0);
        uint256 currentSupply = ulaloToken.totalSupply(); // Changed from initialSupply
        uint256 burnAmount = 200 * 10**18;

        // Reset state first
        _resetAllTokenState();

        // Transfer tokens to burner
        ulaloToken.transfer(burner, burnAmount);

        // Burner burns their own tokens
        vm.prank(burner);
        ulaloToken.burn(burnAmount);

        assertEq(ulaloToken.totalSupply(), currentSupply - burnAmount);
    }
    
    function testFail_UnauthorizedBurn() public {
        // user1 tries to burn without BURNER_ROLE
        vm.prank(user1);
        ulaloToken.burn(100 * 10**18);
    }
    
    // ===== Pause Tests =====
    
    function test_PauseAndUnpause() public {
        _resetAllTokenState();
        
        // Test initial state
        assertFalse(ulaloToken.paused());
        
        // Test successful pause with event
        vm.expectEmit(true, false, false, true);
        emit ContractPaused(pauser);
        vm.prank(pauser);
        ulaloToken.pause();
        assertTrue(ulaloToken.paused());
        
        // Test attempting to pause when already paused
        vm.expectRevert("UlaloToken: contract is already paused");
        vm.prank(pauser);
        ulaloToken.pause();
        
        // Test transfers while paused
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ulaloToken.transfer(user2, 100 * 10**18);
        
        // Test successful unpause
        vm.prank(pauser);
        ulaloToken.unpause();
        assertFalse(ulaloToken.paused());
        
        // Test attempting to unpause when not paused
        vm.expectRevert("UlaloToken: contract is not paused");
        vm.prank(pauser);
        ulaloToken.unpause();
        
        // Verify transfers work after unpause
        vm.prank(user1);
        ulaloToken.transfer(user2, 100 * 10**18);
    }
    
    function testFail_UnauthorizedPause() public {
        vm.prank(user1);
        ulaloToken.pause();
    }
    
    function testFail_UnauthorizedUnpause() public {
        // First pause with authorized pauser
        vm.prank(pauser);
        ulaloToken.pause();
        
        // Attempt to unpause with unauthorized user
        vm.prank(user1);
        ulaloToken.unpause();
    }
    
    // ===== Blacklist Tests =====
    
    function test_BlacklistAndUnblacklist() public {
        _resetAllTokenState();
        
        // Initially not blacklisted
        assertFalse(ulaloToken.blacklisted(user1));
        
        // Blacklist user1
        vm.prank(blacklister);
        ulaloToken.updateBlacklist(user1, true);
        assertTrue(ulaloToken.blacklisted(user1));
        
        // Try to transfer from blacklisted address (should fail)
        vm.expectRevert("UlaloToken: sender is blacklisted");
        vm.prank(user1);
        ulaloToken.transfer(user2, 100 * 10**18);
        
        // Try to transfer to blacklisted address (should fail)
        vm.expectRevert("UlaloToken: recipient is blacklisted");
        vm.prank(user2);
        ulaloToken.transfer(user1, 100 * 10**18);
        
        // Remove from blacklist
        vm.prank(blacklister);
        ulaloToken.updateBlacklist(user1, false);
        assertFalse(ulaloToken.blacklisted(user1));
        
        // Transfer should work now
        vm.prank(user1);
        ulaloToken.transfer(user2, 100 * 10**18);
    }
    
    function testFail_UnauthorizedBlacklist() public {
        vm.prank(user1);
        ulaloToken.updateBlacklist(user2, true);
    }
    
    // ===== Rate Limiting Tests =====
    
    function test_TransferLimitEnforcement() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        // Set transfer limit to 0.1% of total supply
        ulaloToken.setTransferLimitPercentage(1); // 1% limit
        
        uint256 totalSupply = ulaloToken.totalSupply();
        uint256 maxTransfer = totalSupply * 1 / 100;
        
        // Give user1 enough tokens for testing
        ulaloToken.transfer(user1, maxTransfer * 2);
        
        // Transfer just at the limit (should succeed)
        vm.prank(user1);
        ulaloToken.transfer(user2, maxTransfer);
        
        // Transfer exceeding the limit (should fail)
        vm.expectRevert("UlaloToken: transfer exceeds rate limit");
        vm.prank(user1);
        ulaloToken.transfer(user2, maxTransfer + 1);
    }
    
    function test_MinterBypassesRateLimit() public {
        // Set transfer limit to 0.1% of total supply
        ulaloToken.setTransferLimitPercentage(1); // 1% limit
        
        uint256 totalSupply = ulaloToken.totalSupply();
        uint256 maxTransfer = totalSupply * 1 / 100;
        
        // Give minter some tokens
        ulaloToken.transfer(minter, maxTransfer * 2);
        
        // Minter should be able to transfer more than the limit
        vm.prank(minter);
        ulaloToken.transfer(user2, maxTransfer + 1000 * 10**18);
    }
    
    function test_CooldownEnforcement() public {
        // Reset all cooldowns first and ensure we start from a clean state
        _resetAllTokenState();
        
        // Now set the cooldown we want to test
        ulaloToken.setTransferCooldown(1 hours);
        
        // First transfer
        vm.startPrank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        vm.stopPrank();
        
        // Second transfer immediately after (should fail)
        vm.expectRevert("UlaloToken: cooldown period not yet elapsed");
        vm.startPrank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        vm.stopPrank();
        
        // Wait for cooldown to pass
        vm.warp(block.timestamp + 1 hours + 1);
        
        // Transfer should work now
        vm.startPrank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        vm.stopPrank();
    }
    
    function test_AdminBypassesCooldown() public {
        // Set cooldown to 1 hour
        ulaloToken.setTransferCooldown(1 hours);
        
        // Admin should be able to transfer multiple times without waiting
        ulaloToken.transfer(user2, 10 * 10**18);
        ulaloToken.transfer(user2, 10 * 10**18);
        ulaloToken.transfer(user2, 10 * 10**18);
    }
    
    // ===== Configuration Tests =====
    
    function test_SetTransferLimitPercentage() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        ulaloToken.setTransferLimitPercentage(5);
        assertEq(ulaloToken.transferLimitPercentage(), 5);
        
        // Test with 0 (no limit)
        ulaloToken.setTransferLimitPercentage(0);
        assertEq(ulaloToken.transferLimitPercentage(), 0);
        
        // Verify no limit is applied
        vm.prank(user1);
        ulaloToken.transfer(user2, 500 * 10**18); // Large transfer should work
    }
    
    function testFail_InvalidTransferLimitPercentage() public {
        ulaloToken.setTransferLimitPercentage(101); // Over 100%
    }
    
    function test_SetTransferCooldown() public {
        ulaloToken.setTransferCooldown(2 hours);
        assertEq(ulaloToken.transferCooldown(), 2 hours);
        
        // Test with 0 (no cooldown)
        ulaloToken.setTransferCooldown(0);
        assertEq(ulaloToken.transferCooldown(), 0);
        
        // Verify no cooldown is applied
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18); // Second transfer should work
    }
    
    function testFail_UnauthorizedTransferLimitChange() public {
        vm.prank(user1);
        ulaloToken.setTransferLimitPercentage(10);
    }
    
    function testFail_UnauthorizedCooldownChange() public {
        vm.prank(user1);
        ulaloToken.setTransferCooldown(5 hours);
    }
    
    // ===== Recovery Tests =====
    
    function test_RecoverERC20() public {
        // Use a helper to reset token state
        _resetAllTokenState();
        
        // Deploy a separate test token
        UlaloToken testToken = new UlaloToken(
            "Test Token", "TEST",
            owner, owner, owner, owner, owner
        );
        
        // Send some test tokens to the ulaloToken contract
        testToken.transfer(address(ulaloToken), 1000 * 10**18);
        
        // Recover the tokens
        ulaloToken.recoverERC20(address(testToken), 1000 * 10**18);
        
        // Verify the tokens were recovered
        assertEq(testToken.balanceOf(address(ulaloToken)), 0);
        assertEq(testToken.balanceOf(address(this)), initialSupply); // All tokens back to owner
    }
    
    function testFail_RecoverUlaloToken() public {
        // Should not be able to recover the UlaloToken itself
        ulaloToken.recoverERC20(address(ulaloToken), 1000 * 10**18);
    }
    
    function testFail_UnauthorizedRecovery() public {
        UlaloToken testToken = new UlaloToken("Test Token", "TEST",owner, owner, owner, owner, owner);
        testToken.transfer(address(ulaloToken), 1000 * 10**18);
    
        vm.prank(user1);
        ulaloToken.recoverERC20(address(testToken), 1000 * 10**18);
    }
    
    // ===== Edge Cases =====
    
    function test_ZeroTransfers() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        // Try to transfer 0 tokens (should fail)
        vm.startPrank(user1);
        vm.expectRevert("UlaloToken: transfer amount must be greater than zero");
        ulaloToken.transfer(user2, 0);
        vm.stopPrank();
    }
    
    function test_TransferToSelf() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        uint256 initialBalance = ulaloToken.balanceOf(user1);
        
        vm.prank(user1);
        ulaloToken.transfer(user1, 100 * 10**18);
        
        assertEq(ulaloToken.balanceOf(user1), initialBalance);
    }
    
    function test_TransferAllBalance() public {
        // Reset cooldown
        ulaloToken.setTransferCooldown(0);
        
        uint256 initialUser1Balance = ulaloToken.balanceOf(user1);
        
        vm.prank(user1);
        ulaloToken.transfer(user2, initialUser1Balance);
        
        assertEq(ulaloToken.balanceOf(user1), 0);
    }
    
    function testFail_TransferMoreThanBalance() public {
        uint256 initialUser1Balance = ulaloToken.balanceOf(user1);
        
        vm.prank(user1);
        ulaloToken.transfer(user2, initialUser1Balance + 1);
    }
    
    function testFail_TransferFromMoreThanAllowed() public {
        vm.prank(user1);
        ulaloToken.approve(user2, 100 * 10**18);
        
        vm.prank(user2);
        ulaloToken.transferFrom(user1, user2, 101 * 10**18);
    }
    
    // ===== Combined Functionality Tests =====
    
    function test_MultipleMechanismsInteraction() public {
        // Reset all cooldowns first
        _resetAllTokenState();
        
        // Now set up the test parameters
        ulaloToken.setTransferLimitPercentage(2);  // 2% limit
        ulaloToken.setTransferCooldown(30 minutes);
        
        // Blacklist user2
        vm.prank(blacklister);
        ulaloToken.updateBlacklist(user2, true);
        
        // User1 attempts to transfer to blacklisted user2 (should fail)
        vm.expectRevert("UlaloToken: recipient is blacklisted");
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        
        // Unblacklist user2
        vm.prank(blacklister);
        ulaloToken.updateBlacklist(user2, false);
        
        // User1 transfers to user2
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        
        // Try another transfer (should fail due to cooldown)
        vm.expectRevert("UlaloToken: cooldown period not yet elapsed");
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        
        // Wait half the cooldown
        vm.warp(block.timestamp + 15 minutes);
        
        // Try again (should still fail)
        vm.expectRevert("UlaloToken: cooldown period not yet elapsed");
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        
        // Wait for cooldown to fully pass
        vm.warp(block.timestamp + 15 minutes + 1);
        
        // Try a transfer above the rate limit (should fail)
        uint256 totalSupply = ulaloToken.totalSupply();
        uint256 maxTransfer = totalSupply * 2 / 100;
        
        vm.expectRevert("UlaloToken: transfer exceeds rate limit");
        vm.prank(user1);
        ulaloToken.transfer(user2, maxTransfer + 1);
        
        // Now pause the contract
        vm.prank(pauser);
        ulaloToken.pause();
        
        // Try a valid transfer (should fail due to pause)
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
        
        // Unpause
        vm.prank(pauser);
        ulaloToken.unpause();
        
        // Transfer should now work
        vm.prank(user1);
        ulaloToken.transfer(user2, 10 * 10**18);
    }
    
    function _resetAllTokenState() internal {
        // Reset cooldowns
        ulaloToken.setTransferCooldown(0);
        
        // Reset transfer limits
        ulaloToken.setTransferLimitPercentage(0);
        
        // Unpause if paused
        if (ulaloToken.paused()) {
            vm.prank(pauser);
            ulaloToken.unpause();
        }
        
        // Remove any blacklist entries
        if (ulaloToken.blacklisted(user1)) {
            vm.prank(blacklister);
            ulaloToken.updateBlacklist(user1, false);
        }
        if (ulaloToken.blacklisted(user2)) {
            vm.prank(blacklister);
            ulaloToken.updateBlacklist(user2, false);
        }
    }
}

contract AttackingToken {
    UlaloToken public token;
    bool public attacked;
    
    constructor(address _token) {
        token = UlaloToken(_token);
    }
    
    function attack() external {
        token.transfer(msg.sender, 100 * 10**18);
    }
    
    // This function will be called during the token transfer
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal {
        if (!attacked) {
            attacked = true;
            // Try to make another transfer while the first is still processing
            token.transfer(msg.sender, 50 * 10**18);
        }
    }
}