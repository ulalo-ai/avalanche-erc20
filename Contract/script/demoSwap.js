const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
const { getWallet } = require('./config');
require('dotenv').config();

async function demoSwap() {
  console.log("Starting UlaloSwap Demonstration...");
  
  const wallet = getWallet("fuji");
  console.log(`Using wallet address: ${wallet.address}`);
  
  // Load contract addresses from environment or deployment files
  const swapAddress = process.env.ULALO_SWAP_ADDRESS;
  const tokenAddress = process.env.ULALO_TOKEN_ADDRESS;
  
  if (!swapAddress || !tokenAddress) {
    throw new Error("Missing ULALO_SWAP_ADDRESS or ULALO_TOKEN_ADDRESS in environment variables");
  }
  
  console.log(`UlaloSwap address: ${swapAddress}`);
  console.log(`UlaloToken address: ${tokenAddress}`);
  
  // Load contract ABIs
  const swapArtifactPath = path.resolve(__dirname, '../out/UlaloSwap.sol/UlaloSwap.json');
  const tokenArtifactPath = path.resolve(__dirname, '../out/UlaloToken.sol/UlaloToken.json');
  
  const swapArtifact = JSON.parse(fs.readFileSync(swapArtifactPath));
  const tokenArtifact = JSON.parse(fs.readFileSync(tokenArtifactPath));
  
  // Create contract instances
  const swapContract = new ethers.Contract(swapAddress, swapArtifact.abi, wallet);
  const tokenContract = new ethers.Contract(tokenAddress, tokenArtifact.abi, wallet);
  
  // Check AVAX and token balances
  const avaxBalanceBefore = await wallet.provider.getBalance(wallet.address);
  const tokenBalanceBefore = await tokenContract.balanceOf(wallet.address);
  
  console.log("\nWallet Balances Before:");
  console.log(`AVAX: ${ethers.utils.formatEther(avaxBalanceBefore)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(tokenBalanceBefore)} ULA`);
  
  // Approve Ulalo tokens for the swap contract
  console.log("\nApproving Ulalo tokens for the swap contract...");
  const approvalTx = await tokenContract.approve(
    swapAddress,
    ethers.utils.parseEther("1000") // Approve 1000 Ulalo tokens
  );
  await approvalTx.wait();
  console.log(`Approved 1000 Ulalo tokens for the swap contract (tx: ${approvalTx.hash})`);
  
  // Check contract reserves before
  const reserveAVAXBefore = await swapContract.reserve_AVAX();
  const reserveUlaloBefore = await swapContract.reserve_Ulalo();
  console.log("\nContract Reserves Before:");
  console.log(`AVAX: ${ethers.utils.formatEther(reserveAVAXBefore)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(reserveUlaloBefore)} ULA`);
  
  // 1. Add Liquidity
  console.log("\nAdding liquidity...");
  try {
    const liquidity_tx = await swapContract.addLiquidityWithAVAX(
      ethers.utils.parseEther("500"), // 500 Ulalo tokens
      {
        value: ethers.utils.parseEther("0.1"), // 0.1 AVAX
        gasLimit: 500000
      }
    );
    const receipt = await liquidity_tx.wait();
    console.log(`Liquidity added (tx: ${liquidity_tx.hash})`);
    
    // Log liquidity position
    const liquidityBalance = await swapContract.liquidityBalances(wallet.address);
    const totalLiquidity = await swapContract.totalLiquidity();
    const percentage = (liquidityBalance.mul(100)).div(totalLiquidity);
    console.log(`Liquidity position: ${ethers.utils.formatEther(liquidityBalance)} LP (${percentage.toString()}% of pool)`);
  } catch (error) {
    console.error("Error adding liquidity:", error.message);
  }
  
  // Check contract reserves after adding liquidity
  const reserveAVAXAfterLiquidity = await swapContract.reserve_AVAX();
  const reserveUlaloAfterLiquidity = await swapContract.reserve_Ulalo();
  console.log("\nContract Reserves After Adding Liquidity:");
  console.log(`AVAX: ${ethers.utils.formatEther(reserveAVAXAfterLiquidity)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(reserveUlaloAfterLiquidity)} ULA`);
  
  // 2. Swap AVAX for Ulalo
  console.log("\nSwapping AVAX for Ulalo tokens...");
  try {
    // First get a quote
    const avaxAmount = ethers.utils.parseEther("0.01"); // 0.01 AVAX
    const expectedUlalo = await swapContract.getUlaloForAVAX(avaxAmount);
    console.log(`Expected Ulalo tokens: ${ethers.utils.formatEther(expectedUlalo)} ULA`);
    
    // Execute the swap
    const swapTx = await swapContract.swapAVAXForUlalo(
      0, // Min output (0 for demo purposes, in production use a proper slippage value)
      {
        value: avaxAmount,
        gasLimit: 500000
      }
    );
    await swapTx.wait();
    console.log(`Swapped 0.01 AVAX for Ulalo tokens (tx: ${swapTx.hash})`);
  } catch (error) {
    console.error("Error swapping AVAX for Ulalo:", error.message);
  }
  
  // 3. Swap Ulalo for AVAX
  console.log("\nSwapping Ulalo tokens for AVAX...");
  try {
    // First get a quote
    const ulaloAmount = ethers.utils.parseEther("50"); // 50 Ulalo tokens
    const expectedAVAX = await swapContract.getAVAXForUlalo(ulaloAmount);
    console.log(`Expected AVAX: ${ethers.utils.formatEther(expectedAVAX)} AVAX`);
    
    // Execute the swap
    const swapTx = await swapContract.swapUlaloForAVAX(
      ulaloAmount,
      0, // Min output (0 for demo purposes, in production use a proper slippage value)
      { gasLimit: 500000 }
    );
    await swapTx.wait();
    console.log(`Swapped 50 Ulalo tokens for AVAX (tx: ${swapTx.hash})`);
  } catch (error) {
    console.error("Error swapping Ulalo for AVAX:", error.message);
  }
  
  // Check contract reserves after swaps
  const reserveAVAXAfterSwaps = await swapContract.reserve_AVAX();
  const reserveUlaloAfterSwaps = await swapContract.reserve_Ulalo();
  console.log("\nContract Reserves After Swaps:");
  console.log(`AVAX: ${ethers.utils.formatEther(reserveAVAXAfterSwaps)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(reserveUlaloAfterSwaps)} ULA`);
  
  // 4. Remove half of the liquidity
  console.log("\nRemoving half of the liquidity...");
  try {
    const liquidityBalance = await swapContract.liquidityBalances(wallet.address);
    const halfLiquidity = liquidityBalance.div(2);
    
    const removeTx = await swapContract.removeLiquidity(
      halfLiquidity,
      0, // Min AVAX out
      0, // Min Ulalo out
      { gasLimit: 500000 }
    );
    await removeTx.wait();
    console.log(`Removed half of the liquidity (tx: ${removeTx.hash})`);
    
    // Log remaining liquidity position
    const newLiquidityBalance = await swapContract.liquidityBalances(wallet.address);
    const totalLiquidity = await swapContract.totalLiquidity();
    const percentage = (newLiquidityBalance.mul(100)).div(totalLiquidity);
    console.log(`Remaining liquidity: ${ethers.utils.formatEther(newLiquidityBalance)} LP (${percentage.toString()}% of pool)`);
  } catch (error) {
    console.error("Error removing liquidity:", error.message);
  }
  
  // Final contract reserves
  const finalReserveAVAX = await swapContract.reserve_AVAX();
  const finalReserveUlalo = await swapContract.reserve_Ulalo();
  console.log("\nFinal Contract Reserves:");
  console.log(`AVAX: ${ethers.utils.formatEther(finalReserveAVAX)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(finalReserveUlalo)} ULA`);
  
  // Check wallet balances
  const avaxBalance = await wallet.provider.getBalance(wallet.address);
  const ulaloBalance = await tokenContract.balanceOf(wallet.address);
  console.log("\nWallet Final Balances:");
  console.log(`AVAX: ${ethers.utils.formatEther(avaxBalance)} AVAX`);
  console.log(`Ulalo: ${ethers.utils.formatEther(ulaloBalance)} ULA`);
  
  console.log("\nUlaloSwap demonstration completed successfully!");
  console.log("You can view all transactions on the Avalanche Fuji explorer:");
  console.log(`https://testnet.snowtrace.io/address/${wallet.address}`);
}

// Execute the demo
async function main() {
  try {
    await demoSwap();
    console.log("Demo completed successfully!");
  } catch (error) {
    console.error("Demo failed:", error);
    console.error(error.stack);
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });