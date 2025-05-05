// script/deploy_faucet.js
const { getWallet } = require('./config');
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
require('dotenv').config();

async function deployFaucet() {
  console.log("Deploying Updated UlaloTokenFaucet to Avalanche Fuji...");
  const wallet = getWallet("fuji");
  console.log("Deployer address:", wallet.address);
  
  // First make sure the contract is compiled with the latest changes
  console.log("Compiling contracts...");
  try {
    await execPromise("forge build");
    console.log("Contracts compiled successfully");
  } catch (error) {
    console.error("Error compiling contracts:", error.message);
    throw new Error("Contract compilation failed");
  }
  
  // Get the previously deployed UlaloToken address
  const ulaloTokenAddress = process.env.ULALO_TOKEN_ADDRESS;
  if (!ulaloTokenAddress) {
    throw new Error("UlaloToken address not found. Set ULALO_TOKEN_ADDRESS in environment variables.");
  }
  console.log("Found deployed UlaloToken at:", ulaloTokenAddress);

  // Load UlaloToken contract to interact with it
  const tokenArtifactPath = path.resolve(__dirname, '../out/UlaloToken.sol/UlaloToken.json');
  const tokenArtifact = JSON.parse(fs.readFileSync(tokenArtifactPath));
  const tokenContract = new ethers.Contract(
    ulaloTokenAddress,
    tokenArtifact.abi,
    wallet
  );
  
  // Deploy UlaloTokenFaucet
  console.log("Deploying UlaloTokenFaucet with drip functionality...");

  // Load faucet contract artifact
  const faucetArtifactPath = path.resolve(__dirname, '../out/UlaloFaucet.sol/UlaloTokenFaucet.json');
  const faucetArtifact = JSON.parse(fs.readFileSync(faucetArtifactPath));

  // Create contract factory
  const factory = new ethers.ContractFactory(
    faucetArtifact.abi,
    faucetArtifact.bytecode,
    wallet
  );

  // Deploy the contract - NO CONSTRUCTOR ARGS NEEDED
  console.log("Sending deployment transaction...");
  const deployTx = await factory.getDeployTransaction();
  
  // Estimate gas
  const gasEstimate = await wallet.estimateGas(deployTx);
  console.log("Estimated gas:", gasEstimate.toString());
  
  // Add gas limit
  const tx = await wallet.sendTransaction({
    ...deployTx,
    gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
  });
  
  console.log("Deployment transaction sent:", tx.hash);
  console.log("Waiting for confirmation...");
  
  // Wait for transaction to be mined
  const receipt = await tx.wait();
  const faucetAddress = ethers.utils.getContractAddress({
    from: wallet.address,
    nonce: tx.nonce
  });
  
  console.log("UlaloTokenFaucet deployed to:", faucetAddress);
  
  // Initialize the faucet contract instance
  const faucetContract = new ethers.Contract(
    faucetAddress,
    faucetArtifact.abi,
    wallet
  );

  // Set token address in the faucet contract
  console.log("Setting token address in faucet contract...");
  const setTokenTx = await faucetContract.setTokenAddress(ulaloTokenAddress);
  await setTokenTx.wait();
  console.log("Token address set in faucet");

  // Set faucet limit - 1,000,000 tokens
  const faucetLimitAmount = ethers.utils.parseEther("1000000");
  console.log(`Setting faucet limit to 1,000,000 ULALO...`);
  const setLimitTx = await faucetContract.setFaucetLimit(faucetLimitAmount);
  await setLimitTx.wait();
  console.log("Faucet limit set");
  
  // Check if caller has minter role on the token contract
  try {
    // Check if the token has a MINTER_ROLE function (common in ERC20 tokens with roles)
    const MINTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));
    const hasMinterRole = await tokenContract.hasRole(MINTER_ROLE, wallet.address);
    
    if (hasMinterRole) {
      console.log("Deployer has minter role. Minting tokens directly to faucet...");
      
      // Mint 10,000 tokens directly to the faucet
      const mintAmount = ethers.utils.parseEther("10000");
      const mintTx = await tokenContract.mint(faucetAddress, mintAmount);
      await mintTx.wait();
      console.log("Successfully minted 10,000 ULALO tokens to the faucet");
    } else {
      console.log("Deployer does not have minter role. Using transfer instead...");
      
      // Transfer tokens from deployer to faucet
      const transferAmount = ethers.utils.parseEther("10000");
      
      // Check deployer balance first
      const ownerBalance = await tokenContract.balanceOf(wallet.address);
      console.log(`Owner balance: ${ethers.utils.formatEther(ownerBalance)} ULALO`);
      
      if (ownerBalance.lt(transferAmount)) {
        console.warn(`Warning: Insufficient balance to fund faucet. You have ${ethers.utils.formatEther(ownerBalance)} ULALO`);
        console.log("Proceeding without funding the faucet. You can fund it manually later.");
      } else {
        console.log("Transferring 10,000 ULALO tokens to faucet...");
        const transferTx = await tokenContract.transfer(faucetAddress, transferAmount);
        await transferTx.wait();
        console.log("Successfully transferred 10,000 ULALO tokens to the faucet");
      }
    }
  } catch (error) {
    console.log("Could not check minter role, assuming standard ERC20. Using transfer...");
    
    // Transfer tokens from deployer to faucet
    const transferAmount = ethers.utils.parseEther("10000");
    
    // Check deployer balance first
    const ownerBalance = await tokenContract.balanceOf(wallet.address);
    console.log(`Owner balance: ${ethers.utils.formatEther(ownerBalance)} ULALO`);
    
    if (ownerBalance.lt(transferAmount)) {
      console.warn(`Warning: Insufficient balance to fund faucet. You have ${ethers.utils.formatEther(ownerBalance)} ULALO`);
      console.log("Proceeding without funding the faucet. You can fund it manually later.");
    } else {
      console.log("Transferring 10,000 ULALO tokens to faucet...");
      const transferTx = await tokenContract.transfer(faucetAddress, transferAmount);
      await transferTx.wait();
      console.log("Successfully transferred 10,000 ULALO tokens to the faucet");
    }
  }
  
  // Set 10,000 token approval for the faucet to use
  console.log("Approving 10,000 ULALO tokens for the faucet...");
  const approvalAmount = ethers.utils.parseEther("10000");
  const approveTx = await tokenContract.approve(faucetAddress, approvalAmount);
  await approveTx.wait();
  console.log("Successfully approved 10,000 ULALO tokens for the faucet");
  
  // Verify the faucet's balance
  const faucetBalance = await tokenContract.balanceOf(faucetAddress);
  console.log(`Faucet balance: ${ethers.utils.formatEther(faucetBalance)} ULALO`);
  
  // Test drip function
  console.log("\nTesting drip functionality...");
  try {
    // Test dripping tokens to the deployer
    console.log(`Testing drip function to deployer (${wallet.address})...`);
    const dripTx = await faucetContract.drip(wallet.address);
    await dripTx.wait();
    
    // Check updated balance
    const newBalance = await tokenContract.balanceOf(wallet.address);
    console.log("Drip function executed successfully!");
    console.log(`Your new balance: ${ethers.utils.formatEther(newBalance)} ULALO`);
    console.log("Drip functionality is working correctly!");
  } catch (error) {
    console.error("Error testing drip function:", error.message);
    console.log("You can manually test the drip function using the block explorer or another script");
  }

  // Add this after the drip test section
  console.log("\nTesting withdraw functionality...");
  try {
    // Test withdrawing a small amount (0.1 tokens) to your wallet
    const withdrawAmount = ethers.utils.parseEther("0.1");
    console.log(`Testing withdraw function: ${ethers.utils.formatEther(withdrawAmount)} ULALO to deployer...`);
    const withdrawTx = await faucetContract.withdraw(withdrawAmount, wallet.address);
    await withdrawTx.wait();
    
    console.log("Withdraw function executed successfully!");
    console.log(`Transaction hash: ${withdrawTx.hash}`);
  } catch (error) {
    console.error("Error testing withdraw function:", error.message);
  }
  
  // Verify contract on the block explorer
  console.log("\nVerifying contract on the Avalanche Fuji block explorer...");
  try {
    // Step 1: Flatten the contract
    console.log("Flattening contract...");
    await execPromise("forge flatten src/UlaloFaucet.sol > UlaloFaucetFlat.sol");
    console.log("Contract flattened successfully");

    // Step 2: Verify the contract
    console.log("Submitting verification request...");
    const verifyCommand = `forge verify-contract \
      --chain avalanche-fuji \
      --compiler-version 0.8.20 \
      --watch \
      --constructor-args $(cast abi-encode "constructor()") \
      ${faucetAddress} \
      UlaloFaucetFlat.sol:UlaloTokenFaucet \
      --verifier-url "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan" \
      --etherscan-api-key "api"`;
    
    const { stdout, stderr } = await execPromise(verifyCommand);
    
    if (stderr) {
      console.error("Verification error:", stderr);
    }
    
    console.log("Verification output:", stdout);
    console.log("Contract verification submitted. Check the block explorer for status.");
    console.log(`View contract: https://testnet.snowtrace.io/address/${faucetAddress}`);
  } catch (error) {
    console.error("Contract verification failed:", error.message);
    console.log("You can manually verify the contract later using the following command:");
    console.log(`
forge verify-contract \\
  --chain avalanche-fuji \\
  --compiler-version 0.8.20 \\
  --watch \\
  --constructor-args $(cast abi-encode "constructor()") \\
  ${faucetAddress} \\
  src/UlaloFaucet.sol:UlaloTokenFaucet \\
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan" \\
  --etherscan-api-key "api"
    `);
  }
  
  // Display summary
  console.log("\nFaucet Deployment Summary:");
  console.log("----------------------------");
  console.log(`UlaloToken: ${ulaloTokenAddress}`);
  console.log(`UlaloTokenFaucet: ${faucetAddress}`);
  console.log(`Faucet Limit: 1,000,000 ULALO`);
  console.log(`Faucet Balance: ${ethers.utils.formatEther(faucetBalance)} ULALO`);
  console.log(`Drip Amount: 1 ULALO per request`);
  console.log(`Explorer Link: https://testnet.snowtrace.io/address/${faucetAddress}`);
  console.log("----------------------------");
  console.log("Deployment complete!");
  
  // Save deployment info to a JSON file
  const deploymentInfo = {
    faucetAddress,
    tokenAddress: ulaloTokenAddress,
    deploymentTime: new Date().toISOString(),
    faucetLimit: "1,000,000 ULALO",
    faucetBalance: ethers.utils.formatEther(faucetBalance) + " ULALO",
    dripAmount: "1 ULALO per request",
    explorerLink: `https://testnet.snowtrace.io/address/${faucetAddress}`
  };

  fs.writeFileSync(
    'ulalo-faucet-deployment-fuji.json', 
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("Deployment info saved to ulalo-faucet-deployment-fuji.json");
  
  return {
    faucetAddress,
    tokenAddress: ulaloTokenAddress
  };
}

// Execute deployment
async function main() {
  await deployFaucet();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
