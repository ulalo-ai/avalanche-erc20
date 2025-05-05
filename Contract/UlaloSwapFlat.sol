// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// src/interface/IUlaloSwap.sol

/**
 * @title IUlaloSwap
 * @dev Interface for UlaloSwap contract with all required functions and events
 */
interface IUlaloSwap {
    /**
     * @dev Emitted when liquidity is added to the pool
     */
    event LiquidityAdded(address indexed provider, uint amount_AVAX, uint amount_Ulalo, uint liquidity);
    
    /**
     * @dev Emitted when liquidity is removed from the pool
     */
    event LiquidityRemoved(address indexed provider, uint amount_AVAX, uint amount_Ulalo, uint liquidity);
    
    /**
     * @dev Emitted when a swap occurs
     */
    event Swapped(address indexed user, address inputToken, uint amountIn, address outputToken, uint amountOut);
    
    /**
     * @dev Emitted when strict balance check setting is updated
     */
    event StrictBalanceCheckUpdated(bool enabled);
    
    /**
     * @dev Emitted when AVAX transfer fails
     */
    event AVAXTransferFailed(address recipient, uint256 amount);

    /**
     * @dev Returns the address used to represent native AVAX
     */
    function NATIVE_AVAX() external pure returns (address);
    
    /**
     * @dev Returns the address of the Ulalo token
     */
    function token_Ulalo() external view returns (address);
    
    /**
     * @dev Returns the amount of AVAX in the reserves
     */
    function reserve_AVAX() external view returns (uint);
    
    /**
     * @dev Returns the amount of Ulalo in the reserves
     */
    function reserve_Ulalo() external view returns (uint);
    
    /**
     * @dev Returns the liquidity balance of an address
     */
    function liquidityBalances(address provider) external view returns (uint);
    
    /**
     * @dev Returns the total liquidity in the pool
     */
    function totalLiquidity() external view returns (uint);
    
    /**
     * @dev Returns whether strict balance check is enabled
     */
    function strictBalanceCheckEnabled() external view returns (bool);
    
    /**
     * @dev Adds liquidity to the pool with native AVAX
     */
    function addLiquidityWithAVAX(uint amount_Ulalo) external payable;
    
    /**
     * @dev Removes liquidity from the pool
     */
    function removeLiquidity(uint liquidityAmount) external returns (uint256 avaxAmount, uint256 ulaoAmount);
    
    /**
     * @dev Helper function to send AVAX
     */
    function sendAVAX(address to, uint256 amount) external;
    
    /**
     * @dev Swaps AVAX for Ulalo tokens
     */
    function swapAVAXForUlalo(uint minAmountOut) external payable;
    
    /**
     * @dev Swaps Ulalo tokens for AVAX
     */
    function swapUlaloForAVAX(uint amountIn, uint minAmountOut) external;
    
    /**
     * @dev Calculates the amount of AVAX to receive for a given amount of Ulalo
     */
    function getAVAXForUlalo(uint amountIn) external view returns (uint);
    
    /**
     * @dev Calculates the amount of Ulalo to receive for a given amount of AVAX
     */
    function getUlaloForAVAX(uint amountIn) external view returns (uint);
    
    /**
     * @dev Pauses the contract
     */
    function pause() external;
    
    /**
     * @dev Unpauses the contract
     */
    function unpause() external;
    
    /**
     * @dev Sets whether strict balance check is enabled
     */
    function setStrictBalanceCheck(bool _enabled) external;
    
    /**
     * @dev Square root function
     */
    function sqrt(uint input) external pure returns (uint result);
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/utils/Pausable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// src/UlaloSwap.sol

contract UlaloSwap is ReentrancyGuard, Ownable, Pausable, IUlaloSwap {
    address public constant override NATIVE_AVAX = address(0);
    address public override token_Ulalo;

    uint public override reserve_AVAX;
    uint public override reserve_Ulalo;

    mapping(address => uint) public override liquidityBalances;
    uint public override totalLiquidity;

    bool public override strictBalanceCheckEnabled = true;

    constructor(address _token_Ulalo, address initialOwner) 
        Ownable(initialOwner) 
        Pausable() 
    {
        token_Ulalo = _token_Ulalo;
    }

    function addLiquidityWithAVAX(uint amount_Ulalo) external payable override nonReentrant whenNotPaused {
        uint amount_AVAX = msg.value;
        require(amount_AVAX > 0, "Must provide AVAX");
        require(amount_Ulalo > 0, "Must provide Ulalo tokens");

        if (totalLiquidity > 0) {
            if (strictBalanceCheckEnabled) {
                uint256 leftSide = reserve_AVAX * amount_Ulalo;
                uint256 rightSide = reserve_Ulalo * amount_AVAX;
                uint256 tolerance = leftSide / 1000;

                require(
                    (leftSide >= rightSide && leftSide - rightSide <= tolerance) || 
                    (rightSide >= leftSide && rightSide - leftSide <= tolerance),
                    "Imbalanced liquidity addition"
                );
            }
        }

        IERC20(token_Ulalo).transferFrom(msg.sender, address(this), amount_Ulalo);
        
        reserve_AVAX += amount_AVAX;
        reserve_Ulalo += amount_Ulalo;

        uint liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amount_AVAX * amount_Ulalo);
        } else {
            liquidityMinted = min(
                (amount_AVAX * totalLiquidity) / (reserve_AVAX - amount_AVAX),
                (amount_Ulalo * totalLiquidity) / (reserve_Ulalo - amount_Ulalo)
            );
        }

        liquidityBalances[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityAdded(msg.sender, amount_AVAX, amount_Ulalo, liquidityMinted);
    }

    function removeLiquidity(uint liquidityAmount) external override nonReentrant whenNotPaused returns (uint256 avaxAmount, uint256 ulaloAmount) {
        require(liquidityBalances[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        uint amount_AVAX = (liquidityAmount * reserve_AVAX) / totalLiquidity;
        uint amount_Ulalo = (liquidityAmount * reserve_Ulalo) / totalLiquidity;

        liquidityBalances[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        reserve_AVAX -= amount_AVAX;
        reserve_Ulalo -= amount_Ulalo;

        IERC20(token_Ulalo).transfer(msg.sender, amount_Ulalo);
        
        if (tx.origin != msg.sender) {
            emit AVAXTransferFailed(msg.sender, amount_AVAX);
        } else {
            (bool success, ) = msg.sender.call{value: amount_AVAX}("");
            require(success, "AVAX transfer failed");
        }

        emit LiquidityRemoved(msg.sender, amount_AVAX, amount_Ulalo, liquidityAmount);
        return (amount_AVAX, amount_Ulalo);
    }

    function sendAVAX(address to, uint256 amount) external override {
        require(msg.sender == address(this), "Only callable from this contract");
        (bool success, ) = to.call{value: amount}("");
        require(success, "AVAX transfer failed");
    }

    function swapAVAXForUlalo(uint minAmountOut) external payable override nonReentrant whenNotPaused {
        uint amountIn = msg.value;
        require(amountIn > 0, "Must provide AVAX");

        uint amountInWithFee = amountIn * 997 / 1000;
        uint amountOut = (reserve_Ulalo * amountInWithFee) / (reserve_AVAX + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage: amount out too low");

        reserve_AVAX += amountIn;
        reserve_Ulalo -= amountOut;

        IERC20(token_Ulalo).transfer(msg.sender, amountOut);

        emit Swapped(msg.sender, NATIVE_AVAX, amountIn, token_Ulalo, amountOut);
    }

    function swapUlaloForAVAX(uint amountIn, uint minAmountOut) external override nonReentrant whenNotPaused {
        require(amountIn > 0, "Amount must be greater than 0");

        IERC20(token_Ulalo).transferFrom(msg.sender, address(this), amountIn);

        uint amountInWithFee = amountIn * 997 / 1000;
        uint amountOut = (reserve_AVAX * amountInWithFee) / (reserve_Ulalo + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage: amount out too low");

        reserve_Ulalo += amountIn;
        reserve_AVAX -= amountOut;

        (bool success, ) = msg.sender.call{value: amountOut}("");
        require(success, "AVAX transfer failed");

        emit Swapped(msg.sender, token_Ulalo, amountIn, NATIVE_AVAX, amountOut);
    }

    function getAVAXForUlalo(uint amountIn) external view override returns (uint) {
        uint amountInWithFee = amountIn * 997 / 1000;
        return (reserve_AVAX * amountInWithFee) / (reserve_Ulalo + amountInWithFee);
    }

    function getUlaloForAVAX(uint amountIn) external view override returns (uint) {
        uint amountInWithFee = amountIn * 997 / 1000;
        return (reserve_Ulalo * amountInWithFee) / (reserve_AVAX + amountInWithFee);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function setStrictBalanceCheck(bool _enabled) external override onlyOwner {
        strictBalanceCheckEnabled = _enabled;
        emit StrictBalanceCheckUpdated(_enabled);
    }

    function sqrt(uint input) public pure override returns (uint result) {
        if (input > 3) {
            result = input;
            uint temp = input / 2 + 1;
            while (temp < result) {
                result = temp;
                temp = (input / temp + temp) / 2;
            }
        } else if (input != 0) {
            result = 1;
        }
    }

    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    receive() external payable {
        require(msg.sender == address(this), "Direct deposits not allowed");
    }

    fallback() external payable {
        revert("Function not found");
    }
}

