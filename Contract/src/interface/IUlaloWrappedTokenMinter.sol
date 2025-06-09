// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ------------------------------
/// INTERFACES
/// ------------------------------
interface IUlaloWrappedTokenMinter {
    function mintWrapped(address originalToken, address to, uint256 amount, bytes32 srcTxId) external;
    function burnWrapped(address wrappedToken, uint256 amount) external;
    function addWrappedToken(address originalToken, address wrappedToken) external;
}