// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IUlaloSwap.sol";

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
