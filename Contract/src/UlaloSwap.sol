// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UlaloSwap is ReentrancyGuard, Ownable, Pausable {
    address public tokenWAVAX;  // Renamed to reflect wAVAX token

    uint public reserveULA;     // Renamed to reflect native ULA
    uint public reserveWAVAX;   // Renamed to reflect wAVAX token

    mapping(address => uint) public liquidityBalances;
    uint public totalLiquidity;

    bool public strictBalanceCheckEnabled = true;

    event LiquidityAdded(address indexed provider, uint ulaAmount, uint wavaxAmount, uint liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint ulaAmount, uint wavaxAmount, uint liquidityBurned);
    event Swapped(address indexed user, string tokenInType, uint amountIn, string tokenOutType, uint amountOut);
    event ULATransferFailed(address indexed to, uint amount);
    event StrictBalanceCheckUpdated(bool enabled);

    constructor(address _tokenWAVAX, address initialOwner) 
        Ownable(initialOwner) 
        Pausable() 
    {
        tokenWAVAX = _tokenWAVAX;
    }

    function addLiquidityWithWAVAX(uint amountWAVAX) external payable nonReentrant whenNotPaused {
        uint amountULA = msg.value;
        require(amountULA > 0, "Must provide ULA");
        require(amountWAVAX > 0, "Must provide wAVAX tokens");

        if (totalLiquidity > 0) {
            if (strictBalanceCheckEnabled) {
                uint256 leftSide = reserveULA * amountWAVAX;
                uint256 rightSide = reserveWAVAX * amountULA;
                uint256 tolerance = leftSide / 1000;

                require(
                    (leftSide >= rightSide && leftSide - rightSide <= tolerance) || 
                    (rightSide >= leftSide && rightSide - leftSide <= tolerance),
                    "Imbalanced liquidity addition"
                );
            }
        }

        IERC20(tokenWAVAX).transferFrom(msg.sender, address(this), amountWAVAX);
        
        reserveULA += amountULA;
        reserveWAVAX += amountWAVAX;

        uint liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amountULA * amountWAVAX);
        } else {
            liquidityMinted = min(
                (amountULA * totalLiquidity) / (reserveULA - amountULA),
                (amountWAVAX * totalLiquidity) / (reserveWAVAX - amountWAVAX)
            );
        }

        liquidityBalances[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityAdded(msg.sender, amountULA, amountWAVAX, liquidityMinted);
    }

    function removeLiquidity(uint256 liquidityAmount) external nonReentrant whenNotPaused returns (uint256 ulaAmount, uint256 wavaxAmount) {
        require(liquidityBalances[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        uint amountULA = (liquidityAmount * reserveULA) / totalLiquidity;
        uint amountWAVAX = (liquidityAmount * reserveWAVAX) / totalLiquidity;

        liquidityBalances[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        reserveULA -= amountULA;
        reserveWAVAX -= amountWAVAX;

        IERC20(tokenWAVAX).transfer(msg.sender, amountWAVAX);
        
        // Transfer ULA - THIS IS THE PROBLEMATIC PART
        (bool success, ) = msg.sender.call{value: amountULA}("");
        if (!success) {
            emit ULATransferFailed(msg.sender, amountULA);
        }
        
        emit LiquidityRemoved(msg.sender, amountULA, amountWAVAX, liquidityAmount);
        return (amountULA, amountWAVAX);
    }

    function sendAVAX(address to, uint256 amount) external nonReentrant whenNotPaused {
        require(msg.sender == address(this), "Only callable from this contract");
        (bool success, ) = to.call{value: amount}("");
        require(success, "AVAX transfer failed");
    }

    function swapULAForWAVAX(uint minAmountOut) external payable nonReentrant whenNotPaused {
        uint amountIn = msg.value;
        require(amountIn > 0, "Must provide ULA");

        uint amountInWithFee = amountIn * 997 / 1000;
        uint amountOut = (reserveWAVAX * amountInWithFee) / (reserveULA + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage: amount out too low");

        reserveULA += amountIn;
        reserveWAVAX -= amountOut;

        IERC20(tokenWAVAX).transfer(msg.sender, amountOut);

        emit Swapped(msg.sender, "Native ULA", amountIn, "wAVAX", amountOut);
    }

    function swapWAVAXForULA(uint amountIn, uint minAmountOut) external nonReentrant whenNotPaused {
        require(amountIn > 0, "Amount must be greater than 0");

        IERC20(tokenWAVAX).transferFrom(msg.sender, address(this), amountIn);

        uint amountInWithFee = amountIn * 997 / 1000;
        uint amountOut = (reserveULA * amountInWithFee) / (reserveWAVAX + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage: amount out too low");

        reserveWAVAX += amountIn;
        reserveULA -= amountOut;

        (bool success, ) = msg.sender.call{value: amountOut}("");
        require(success, "ULA transfer failed");

        emit Swapped(msg.sender, "wAVAX", amountIn, "Native ULA", amountOut);
    }

    function getULAForWAVAX(uint amountIn) external view returns (uint) {
        uint amountInWithFee = amountIn * 997 / 1000;
        return (reserveULA * amountInWithFee) / (reserveWAVAX + amountInWithFee);
    }

    function getWAVAXForULA(uint amountIn) external view returns (uint) {
        uint amountInWithFee = amountIn * 997 / 1000;
        return (reserveWAVAX * amountInWithFee) / (reserveULA + amountInWithFee);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setStrictBalanceCheck(bool _enabled) external onlyOwner {
        strictBalanceCheckEnabled = _enabled;
        emit StrictBalanceCheckUpdated(_enabled);
    }

    function sqrt(uint input) public pure returns (uint result) {
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

    receive() external payable {}
}
