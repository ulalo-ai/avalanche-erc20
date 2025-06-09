const { ethers } = require("ethers");
require("dotenv").config();

async function main() {
  console.log("📝 Starting deployment for TokenLocker contract");
  console.log("==============================================");

  // Connect to the Fuji C-Chain
  const provider = new ethers.providers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc");
  
  // Load wallet from private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("❌ ERROR: Missing PRIVATE_KEY in .env file");
    process.exit(1);
  }
  
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log(`🔑 Using deployer address: ${wallet.address}`);
  
  // Check wallet balance
  const balance = await provider.getBalance(wallet.address);
  const balanceInAvax = ethers.utils.formatEther(balance);
  console.log(`💰 Deployer balance: ${balanceInAvax} AVAX`);
  
  if (balance.lt(ethers.utils.parseEther("0.1"))) {
    console.warn("⚠️  WARNING: Low balance for deployment. Recommended at least 0.1 AVAX");
  }

  // Get the contract factory
  console.log("🔧 Compiling contracts...");
  
  // Load the compiled contract artifacts
  const TokenLockerArtifact = require("../out/FujiCChainBridge.sol/TokenLocker.json");
  
  // Create a contract factory
  const TokenLocker = new ethers.ContractFactory(
    TokenLockerArtifact.abi,
    TokenLockerArtifact.bytecode,
    wallet
  );
  
  console.log("🚀 Deploying TokenLocker contract...");
  
  // Deploy the contract with constructor arguments
  const locker = await TokenLocker.deploy();
  
  console.log(`⏳ Waiting for deployment transaction: ${locker.deployTransaction.hash}`);
  await locker.deployed();
  
  console.log(`✅ TokenLocker contract deployed at: ${locker.address}`);
  
  // Verify the contract if API key is available
  if (process.env.AVALANCHE_API_KEY) {
    console.log("🔍 Waiting for block confirmations before verification...");
    // Wait for 6 block confirmations for Avalanche
    await locker.deployTransaction.wait(6);
    
    console.log("🔍 Starting contract verification...");
    try {
      await hre.run("verify:verify", {
        address: locker.address,
        constructorArguments: []
      });
      console.log("✅ Contract verified successfully");
    } catch (error) {
      console.error("❌ Verification error:", error);
    }
  } else {
    console.log("ℹ️  Skipping contract verification. Set AVALANCHE_API_KEY in .env to enable.");
  }

  // Log deployment details for easy reference
  console.log("\n📋 Deployment Summary");
  console.log("==============================================");
  console.log(`Network:          Avalanche Fuji C-Chain (Chain ID: 43113)`);
  console.log(`RPC:              https://api.avax-test.network/ext/bc/C/rpc`);
  console.log(`TokenLocker:      ${locker.address}`);
  console.log(`Admin:            ${wallet.address}`);
  console.log(`Transaction Hash: ${locker.deployTransaction.hash}`);
  console.log(`Block:            ${locker.deployTransaction.blockNumber}`);
  console.log(`Gas Used:         ${locker.deployTransaction.gasLimit.toString()}`);
  console.log("==============================================");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });