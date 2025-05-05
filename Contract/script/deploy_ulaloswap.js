// script/deploy_ulaloswap.js
const { deployContract, saveDeploymentAddress, getWallet, getDeploymentAddress } = require('./config');
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function main() {
  console.log("Deploying UlaloSwap (with native AVAX) to Avalanche Fuji...");
  const wallet = getWallet("fuji");
  console.log("Deployer address:", wallet.address);
  
  // Get the previously deployed UlaloToken address
  let ulaloTokenAddress;
  
  // Try to get from saved deployment
  try {
    ulaloTokenAddress = await getDeploymentAddress("ULALO_TOKEN_ADDRESS");
  } catch (err) {
    // Fallback to env variable
    ulaloTokenAddress = process.env.ULALO_TOKEN_ADDRESS;
  }
  
  // If still not found, try to read from deployment file
  if (!ulaloTokenAddress) {
    try {
      const deploymentFile = `ulalo-token-deployment-fuji.json`;
      if (fs.existsSync(deploymentFile)) {
        const deploymentData = JSON.parse(fs.readFileSync(deploymentFile));
        ulaloTokenAddress = deploymentData.token.address;
      }
    } catch (err) {
      console.log("Could not read from deployment file:", err.message);
    }
  }
  
  if (!ulaloTokenAddress) {
    throw new Error("Ulalo token address not found. Please deploy tokens first using deploy_UlaloToken.js");
  }
  
  console.log("Using ULALO token:", ulaloTokenAddress);
  
  // Deploy UlaloSwap with native AVAX support
  const swap = await deployContract(
    "UlaloSwap",
    "UlaloSwap",
    [ulaloTokenAddress, wallet.address], // [ulaloTokenAddress, feeCollector]
    "fuji"
  );
  await saveDeploymentAddress("ULALO_SWAP_ADDRESS", swap.address);
  console.log("UlaloSwap deployed to:", swap.address);
  
  // Add initial liquidity
  console.log("Setting up initial liquidity...");
  
  // Load UlaloToken ABI from compiled contract
  const tokenArtifactPath = path.resolve(__dirname, '../out/UlaloToken.sol/UlaloToken.json');
  let ulaloTokenAbi;
  
  try {
    const tokenArtifact = JSON.parse(fs.readFileSync(tokenArtifactPath));
    ulaloTokenAbi = tokenArtifact.abi;
  } catch (err) {
    console.log("Could not read token artifact, using minimal ABI");
    ulaloTokenAbi = [
      "function mint(address to, uint256 amount) public", 
      "function approve(address spender, uint256 amount) public returns (bool)",
      "function balanceOf(address account) external view returns (uint256)"
    ];
  }
  
  // Get Ulalo token contract
  const ulaloToken = new ethers.Contract(
    ulaloTokenAddress,
    ulaloTokenAbi,
    wallet
  );
  
  // Initial liquidity amounts
  const initialAvax = process.env.INITIAL_AVAX_LIQUIDITY 
    ? ethers.utils.parseEther(process.env.INITIAL_AVAX_LIQUIDITY) 
    : ethers.utils.parseEther("1"); // Default: 1 AVAX
    
  const initialUlalo = process.env.INITIAL_ULALO_LIQUIDITY 
    ? ethers.utils.parseEther(process.env.INITIAL_ULALO_LIQUIDITY)
    : ethers.utils.parseEther("10000"); // Default: 10,000 ULALO
  
  console.log(`Adding initial liquidity: ${ethers.utils.formatEther(initialAvax)} AVAX and ${ethers.utils.formatEther(initialUlalo)} ULALO`);
  
  // Check deployer's token balance
  const balance = await ulaloToken.balanceOf(wallet.address);
  console.log(`Current ULALO balance: ${ethers.utils.formatEther(balance)}`);
  
  // Mint Ulalo tokens if necessary
  if (balance.lt(initialUlalo)) {
    console.log("Minting Ulalo tokens for liquidity...");
    try {
      const mintTx = await ulaloToken.mint(wallet.address, initialUlalo);
      await mintTx.wait();
      console.log("Minted tokens successfully");
    } catch (err) {
      console.log("Could not mint tokens (may not have minter role), using available balance:", err.message);
      // Continue with current balance
    }
  }
  
  // Check AVAX balance
  const avaxBalance = await wallet.getBalance();
  console.log(`Current AVAX balance: ${ethers.utils.formatEther(avaxBalance)}`);
  
  if (avaxBalance.lt(initialAvax.add(ethers.utils.parseEther("0.01")))) {
    throw new Error(`Insufficient AVAX balance. Need at least ${ethers.utils.formatEther(initialAvax.add(ethers.utils.parseEther("0.01")))} AVAX`);
  }
  
  // Approve Ulalo tokens
  console.log("Approving Ulalo tokens for swap contract...");
  const approveTx = await ulaloToken.approve(swap.address, initialUlalo);
  await approveTx.wait();
  console.log("Tokens approved");
  
  // Load full swap ABI
  const swapArtifactPath = path.resolve(__dirname, '../out/UlaloSwap.sol/UlaloSwap.json');
  let swapAbi;
  
  try {
    const swapArtifact = JSON.parse(fs.readFileSync(swapArtifactPath));
    swapAbi = swapArtifact.abi;
  } catch (err) {
    console.log("Could not read swap artifact, using minimal ABI");
    swapAbi = ["function addLiquidityWithAVAX(uint amount_Ulalo) external payable"];
  }
  
  // Create contract instance with the addLiquidityWithAVAX function
  const swapContract = new ethers.Contract(
    swap.address,
    swapAbi,
    wallet
  );
  
  // Add liquidity
  console.log("Adding initial liquidity...");
  try {
    const addLiqTx = await swapContract.addLiquidityWithAVAX(initialUlalo, {
      value: initialAvax,
      gasLimit: 3000000 // Setting higher gas limit for safety
    });
    
    console.log(`Transaction hash: ${addLiqTx.hash}`);
    console.log("Waiting for transaction confirmation...");
    await addLiqTx.wait();
    console.log("Initial liquidity added successfully!");
  } catch (error) {
    console.error("Failed to add liquidity:", error);
    console.log("Continue without adding initial liquidity. You can add it manually later.");
  }
  
  // Save deployment info
  const deploymentInfo = {
    network: "fuji",
    ulaloToken: ulaloTokenAddress,
    ulaloSwap: swap.address,
    initialLiquidity: {
      avax: ethers.utils.formatEther(initialAvax),
      ulalo: ethers.utils.formatEther(initialUlalo)
    },
    timestamp: new Date().toISOString()
  };
  
  const filename = `ulalo-swap-deployment-fuji.json`;
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\nDeployment info saved to ${filename}`);
  
  console.log("\n=== UlaloSwap Deployment Summary ===");
  console.log(`ULALO Token: ${ulaloTokenAddress}`);
  console.log(`UlaloSwap: ${swap.address}`);
  console.log(`Initial AVAX: ${ethers.utils.formatEther(initialAvax)} AVAX`);
  console.log(`Initial ULALO: ${ethers.utils.formatEther(initialUlalo)} ULALO`);
  console.log("Deployment complete!");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });