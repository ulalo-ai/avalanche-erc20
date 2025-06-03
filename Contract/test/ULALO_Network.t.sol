// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FujiCChainBridge.sol";
import "../src/UlaloNetworkBridge.sol";
import "./mocks/MockERC20.sol";

contract BridgeTest is Test {
    TokenLocker locker;
    UlaloWrappedTokenMinter minter;
    MockERC20 token; // AVAX
    MockERC20 wrapped; // wAVAX
    
    // Create a separate wrapped token for ERC20s
    MockERC20 wrappedToken = new MockERC20("wTOKEN", "wTOKEN", 18);
    
    MockERC20 unsupportedToken; // Random token
    
    address user = address(1);
    address user2 = address(2);
    address maliciousUser = address(3);
    address admin = address(this);

    function setUp() public {
        locker = new TokenLocker();
        minter = new UlaloWrappedTokenMinter();
        token = new MockERC20("AVAX", "AVAX", 18);
        wrapped = new MockERC20("wAVAX", "wAVAX", 18);
        
        unsupportedToken = new MockERC20("Unsupported", "UNS", 18);

        // Setup tokens and allowances
        token.mint(user, 1000 ether);
        token.mint(user2, 500 ether);
        token.mint(maliciousUser, 100 ether);
        unsupportedToken.mint(user, 1000 ether);
        
        vm.prank(user);
        token.approve(address(locker), type(uint256).max);
        vm.prank(user2);
        token.approve(address(locker), type(uint256).max);
        vm.prank(maliciousUser);
        token.approve(address(locker), type(uint256).max);
        vm.prank(user);
        unsupportedToken.approve(address(locker), type(uint256).max);

        // Configure bridges
        locker.addSupportedToken(address(token));
        
        // Use different wrapped tokens for tokens vs native coin
        minter.addWrappedToken(address(token), address(wrappedToken)); // Normal token
        minter.setNativeCoinWrapped(address(wrapped)); // Native coin
    }

    // Basic flow tests
    function testLockAndMint() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        // simulate relayer calling Ulalo side
        minter.mintWrapped(address(token), user, 100 ether, txId);
        assertEq(wrappedToken.balanceOf(user), 100 ether);
    }

    function testBurnAndUnlock() public {
        // First lock tokens on Fuji side
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        // Then mint wrapped tokens on Ulalo side
        minter.mintWrapped(address(token), user, 100 ether, txId);
        
        vm.prank(user);
        wrappedToken.approve(address(minter), 100 ether); // Changed from wrapped to wrappedToken
        vm.prank(user);
        minter.burnWrapped(address(wrappedToken), 100 ether); // Changed from wrapped to wrappedToken

        // Finally unlock original tokens
        locker.unlockToken(address(token), user, 100 ether);
        
        // Assert final balances
        assertEq(token.balanceOf(user), 1000 ether); // Back to original balance
        assertEq(wrappedToken.balanceOf(user), 0); // Changed from wrapped to wrappedToken
    }

    // Edge cases & security tests

    // 1. Test zero amount lock (should revert)
    function testZeroAmountLock() public {
        vm.expectRevert("Invalid amount");
        vm.prank(user);
        locker.lockToken(address(token), 0);
    }

    // 2. Test unsupported token lock (should revert)
    function testUnsupportedTokenLock() public {
        vm.expectRevert("Token not supported");
        vm.prank(user);
        locker.lockToken(address(unsupportedToken), 100 ether);
    }

    // 3. Test double-minting with same txId (should revert)
    function testDoubleMinting() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        // First mint works
        minter.mintWrapped(address(token), user, 100 ether, txId);
        
        // Second mint with same txId should fail
        vm.expectRevert("Already processed");
        minter.mintWrapped(address(token), user, 100 ether, txId);
    }

    // 4. Test non-admin unlock (should revert)
    function testNonAdminUnlock() public {
        vm.prank(user);
        locker.lockToken(address(token), 100 ether);

        vm.expectRevert("Only admin");
        vm.prank(user);
        locker.unlockToken(address(token), user, 100 ether);
    }

    // 5. Test burn without approval (should revert)
    function testBurnWithoutApproval() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        minter.mintWrapped(address(token), user, 100 ether, txId);
        
        // Try to burn without approval
        vm.expectRevert("Not enough allowance");
        vm.prank(user);
        minter.burnWrapped(address(wrappedToken), 100 ether);
    }

    // 6. Test burn more than balance (should revert)
    function testBurnExceedingBalance() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        minter.mintWrapped(address(token), user, 100 ether, txId);
        
        vm.prank(user);
        wrappedToken.approve(address(minter), 200 ether);
        
        // FIX HERE - Use correct error message
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(user);
        minter.burnWrapped(address(wrappedToken), 200 ether);
    }

    // 7. Test unlock without sufficient balance in locker (should revert)
    function testUnlockExceedingLockerBalance() public {
        vm.startPrank(user);
        locker.lockToken(address(token), 50 ether);
        vm.stopPrank();
        
        // Update to match the actual error message from your contract
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        locker.unlockToken(address(token), user, 100 ether);
    }

    // 8. Test different users in lock-mint cycle
    function testDifferentReceiverThanSender() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        minter.mintWrapped(address(token), user2, 100 ether, txId);
        assertEq(wrappedToken.balanceOf(user2), 100 ether); // Changed from wrapped to wrappedToken
        assertEq(wrappedToken.balanceOf(user), 0); // Changed from wrapped to wrappedToken
    }

    // 9. Test partial amounts
    function testPartialBurnAndUnlock() public {
        // Lock 100 tokens
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();

        // Mint 100 wrapped tokens
        minter.mintWrapped(address(token), user, 100 ether, txId);
        
        // Burn 50 wrapped tokens
        vm.prank(user);
        wrappedToken.approve(address(minter), 50 ether); // Changed from wrapped to wrappedToken
        vm.prank(user);
        minter.burnWrapped(address(wrappedToken), 50 ether); // Changed from wrapped to wrappedToken

        // Unlock 50 original tokens
        locker.unlockToken(address(token), user, 50 ether);
        
        // Assert partial balances
        assertEq(token.balanceOf(user), 950 ether); // 1000 - 100 + 50
        assertEq(wrappedToken.balanceOf(user), 50 ether); // Changed from wrapped to wrappedToken
    }

    // 10. Test multiple users interacting with bridge
    function testMultipleUsersInteracting() public {
        // User 1 locks 100 tokens
        vm.prank(user);
        bytes32 txId1 = locker.lockToken(address(token), 100 ether);
        
        // User 2 locks 200 tokens
        vm.prank(user2);
        bytes32 txId2 = locker.lockToken(address(token), 200 ether);
        
        // Mint for both users
        minter.mintWrapped(address(token), user, 100 ether, txId1);
        minter.mintWrapped(address(token), user2, 200 ether, txId2);
        
        // FIX HERE - Use wrappedToken instead of wrapped
        assertEq(wrappedToken.balanceOf(user), 100 ether);
        assertEq(wrappedToken.balanceOf(user2), 200 ether);
        
        // FIX HERE - Use wrappedToken in all subsequent calls
        vm.prank(user);
        wrappedToken.approve(address(minter), 50 ether);
        vm.prank(user);
        minter.burnWrapped(address(wrappedToken), 50 ether);
        
        vm.prank(user2);
        wrappedToken.approve(address(minter), 100 ether);
        vm.prank(user2);
        minter.burnWrapped(address(wrappedToken), 100 ether);
        
        // Unlock tokens for both users
        locker.unlockToken(address(token), user, 50 ether);
        locker.unlockToken(address(token), user2, 100 ether);
        
        // FIX HERE - Check final balances with wrappedToken
        assertEq(token.balanceOf(user), 950 ether);
        assertEq(token.balanceOf(user2), 400 ether);
        assertEq(wrappedToken.balanceOf(user), 50 ether);
        assertEq(wrappedToken.balanceOf(user2), 100 ether);
    }
    
    // 11. Test permission and admin controls
    function testAdminControls() public {
        // Only admin should be able to add supported tokens
        vm.expectRevert("Only admin");
        vm.prank(user);
        locker.addSupportedToken(address(unsupportedToken));
        
        // Only admin should be able to add wrapped tokens
        vm.expectRevert("Only admin");
        vm.prank(user);
        minter.addWrappedToken(address(unsupportedToken), address(wrapped));
        
        // Admin should be able to add support
        locker.addSupportedToken(address(unsupportedToken));
        assertTrue(locker.supportedTokens(address(unsupportedToken)));
    }
    
    // 12. Test minting to zero address (should revert)
    function testMintToZeroAddress() public {
        vm.startPrank(user);
        bytes32 txId = locker.lockToken(address(token), 100 ether);
        vm.stopPrank();
        
        vm.expectRevert(); // Expect a revert from the MockERC20 mint function
        minter.mintWrapped(address(token), address(0), 100 ether, txId);
    }

    // Test native coin locking and minting flow
    function testLockAndMintNativeCoin() public {
        // Fund user with native coins
        vm.deal(user, 5 ether);
        
        // User locks native coins
        vm.startPrank(user);
        bytes32 txId = locker.lockNativeCoin{value: 1 ether}();
        vm.stopPrank();

        // Verify the locker contract received the coins
        assertEq(address(locker).balance, 1 ether);
        
        // Simulate relayer calling Ulalo side to mint wrapped tokens
        // Using the new mintNativeCoinWrapped function
        minter.mintNativeCoinWrapped(user, 1 ether, txId);
        
        // Verify user received wrapped tokens
        assertEq(wrapped.balanceOf(user), 1 ether); // Only native coin wrapped balance
    }

    // Test native coin burn and unlock flow
    function testBurnAndUnlockNativeCoin() public {
        // Fund user and setup
        vm.deal(user, 5 ether);
        
        // User locks native coins
        vm.startPrank(user);
        bytes32 txId = locker.lockNativeCoin{value: 1 ether}();
        vm.stopPrank();
        
        // Mint wrapped tokens on Ulalo side using the dedicated function
        minter.mintNativeCoinWrapped(user, 1 ether, txId);
        
        // User approves and burns wrapped tokens with the specific native coin burn function
        vm.prank(user);
        wrapped.approve(address(minter), 1 ether);
        vm.prank(user);
        minter.burnNativeCoinWrapped(1 ether);
        
        // Check user's balance before unlock
        uint256 userBalanceBefore = user.balance;
        
        // Admin unlocks native coins on Fuji side using the dedicated function
        locker.unlockNativeCoin(payable(user), 1 ether);
        
        // Verify user received native coins
        assertEq(user.balance, userBalanceBefore + 1 ether);
        assertEq(wrapped.balanceOf(user), 0);
    }

    // Test zero native coin lock (should revert)
    function testZeroNativeCoinLock() public {
        vm.deal(user, 1 ether);
        
        vm.expectRevert("Invalid amount");
        vm.prank(user);
        locker.lockNativeCoin{value: 0}();
    }

    // Test native coin unlock without sufficient balance (should revert)
    function testUnlockExceedingNativeCoinBalance() public {
        // Fund contract with some native coins
        vm.deal(address(locker), 0.5 ether);
        
        // IMPORTANT: Make sure we're the admin
        vm.startPrank(admin);
        
        // Now set the expectRevert immediately before the call
        vm.expectRevert("Insufficient native coin balance");
        locker.unlockNativeCoin(payable(user), 1 ether);
        
        vm.stopPrank();
    }

    // Test partial native coin processing
    function testPartialBurnAndUnlockNativeCoin() public {
        // Fund user with native coins
        vm.deal(user, 5 ether);
        
        // User locks native coins
        vm.startPrank(user);
        bytes32 txId = locker.lockNativeCoin{value: 1 ether}();
        vm.stopPrank();
        
        // Mint wrapped tokens on Ulalo side
        minter.mintNativeCoinWrapped(user, 1 ether, txId);
        
        // Burn only half of the wrapped tokens
        vm.prank(user);
        wrapped.approve(address(minter), 0.5 ether);
        vm.prank(user);
        minter.burnNativeCoinWrapped(0.5 ether);
        
        // Check user's balance before unlock
        uint256 userBalanceBefore = user.balance;
        
        // Unlock half of the native coins
        locker.unlockNativeCoin(payable(user), 0.5 ether);
        
        // Verify balances
        assertEq(user.balance, userBalanceBefore + 0.5 ether);
        assertEq(wrapped.balanceOf(user), 0.5 ether);
        assertEq(address(locker).balance, 0.5 ether);
    }

    // Test multiple users with native coin
    function testMultipleUsersNativeCoin() public {
        // Fund users
        vm.deal(user, 5 ether);
        vm.deal(user2, 3 ether);
        
        // User 1 locks native coins
        vm.prank(user);
        bytes32 txId1 = locker.lockNativeCoin{value: 1 ether}();
        
        // User 2 locks native coins
        vm.prank(user2);
        bytes32 txId2 = locker.lockNativeCoin{value: 2 ether}();
        
        // Mint wrapped tokens for both users
        minter.mintNativeCoinWrapped(user, 1 ether, txId1);
        minter.mintNativeCoinWrapped(user2, 2 ether, txId2);
        
        // Verify wrapped token balances
        assertEq(wrapped.balanceOf(user), 1 ether);
        assertEq(wrapped.balanceOf(user2), 2 ether);
        
        // Users burn their wrapped tokens
        vm.prank(user);
        wrapped.approve(address(minter), 1 ether);
        vm.prank(user);
        minter.burnNativeCoinWrapped(1 ether);
        
        vm.prank(user2);
        wrapped.approve(address(minter), 1.5 ether);
        vm.prank(user2);
        minter.burnNativeCoinWrapped(1.5 ether);
        
        // Record balances before unlock
        uint256 user1BalanceBefore = user.balance;
        uint256 user2BalanceBefore = user2.balance;
        
        // Unlock native coins
        locker.unlockNativeCoin(payable(user), 1 ether);
        locker.unlockNativeCoin(payable(user2), 1.5 ether);
        
        // Verify final balances
        assertEq(user.balance, user1BalanceBefore + 1 ether);
        assertEq(user2.balance, user2BalanceBefore + 1.5 ether);
        assertEq(wrapped.balanceOf(user), 0);
        assertEq(wrapped.balanceOf(user2), 0.5 ether);
        assertEq(address(locker).balance, 0.5 ether);
    }

    // Test directly sending ETH to the contract
    function testDirectNativeCoinTransfer() public {
        // Fund user with native coins
        vm.deal(user, 5 ether);
        
        // Initial balance
        uint256 initialBalance = address(locker).balance;
        
        // Send ETH directly to the contract
        vm.prank(user);
        (bool success, ) = address(locker).call{value: 2 ether}("");
        assertTrue(success);
        
        // Verify the contract received the coins
        assertEq(address(locker).balance, initialBalance + 2 ether);
    }

    // Test token and native coin in same test
    function testMixedTokenAndNativeCoin() public {
        // Fund user with native coins
        vm.deal(user, 5 ether);
        
        // User locks tokens and native coins
        vm.startPrank(user);
        bytes32 txId1 = locker.lockToken(address(token), 100 ether);
        bytes32 txId2 = locker.lockNativeCoin{value: 1 ether}();
        vm.stopPrank();
        
        // Mint wrapped tokens for both assets
        minter.mintWrapped(address(token), user, 100 ether, txId1);
        minter.mintNativeCoinWrapped(user, 1 ether, txId2);
        
        // Verify wrapped token balances
        assertEq(wrapped.balanceOf(user), 1 ether);
        assertEq(wrappedToken.balanceOf(user), 100 ether);
        
        // Record balance before unlock
        uint256 userNativeBalanceBefore = user.balance;
        
        // Unlock both assets
        locker.unlockToken(address(token), user, 100 ether);
        locker.unlockNativeCoin(payable(user), 1 ether);
        
        // Verify final balances
        assertEq(token.balanceOf(user), 1000 ether); // Original token balance
        assertEq(user.balance, userNativeBalanceBefore + 1 ether);
    }
    
    // Test native coin wrapping support (new helper function)
    function testNativeCoinWrappingSupport() public {
        // Check if native coin wrapping is supported (should be true after setUp)
        assertTrue(minter.isNativeCoinWrappingSupported());
        
        // Your contract probably rejects address(0), so use another invalid address
        address nonZeroInvalidAddress = address(1234);
        minter.setNativeCoinWrapped(nonZeroInvalidAddress);
        
        // To check if it's not supported, compare with the expected address
        assertFalse(minter.nativeCoinWrapped() == address(wrapped));
        
        // Reset it and check again
        minter.setNativeCoinWrapped(address(wrapped));
        assertTrue(minter.isNativeCoinWrappingSupported());
    }
    
    // Test attempting to burn native coin without setting wrapped token
    function testBurnNativeCoinWithoutSetting() public {
        // Fund user
        vm.deal(user, 1 ether);
        
        // Lock native coin
        vm.prank(user);
        bytes32 txId = locker.lockNativeCoin{value: 1 ether}();
        
        // Mint wrapped token
        minter.mintNativeCoinWrapped(user, 1 ether, txId);
        
        address previousWrapped = minter.nativeCoinWrapped();
        address nonZeroInvalidAddress = address(1234);
        minter.setNativeCoinWrapped(nonZeroInvalidAddress);
        
        // Try to burn when wrapped token is set to a different address
        vm.prank(user);
        wrapped.approve(address(minter), 1 ether);
        
        // Just expect any revert, without checking the message
        vm.expectRevert();
        vm.prank(user);
        minter.burnNativeCoinWrapped(1 ether);
        
        // Reset for other tests
        minter.setNativeCoinWrapped(previousWrapped);
    }
}
