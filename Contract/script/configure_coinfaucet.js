const { ethers } = require('ethers');
const fs = require('fs');
require('dotenv').config();

// Configuration options
const CONFIG = {
  // Contract address (update this with your deployed contract address)
  contractAddress: "0x61DD73857c56d83d1b96Ec29c21b17aE38385e24", // Fill this with your deployed contract address
  
  // Network details
  rpcUrl: "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
  chainId: 237776,
  networkName: "Ulalo Network",
  
  // New settings
  dripAmount: "0.1", // Amount to drip per request (in native token, e.g. 0.01 AVAX)
  faucetLimit: "10000",  // Total faucet limit (in native token, e.g. 1.0 AVAX)
};

// Contract ABI (just the functions we need)
const CONTRACT_ABI = [
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "newAmount",
        "type": "uint256"
      }
    ],
    "name": "setDripAmount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "newLimit",
        "type": "uint256"
      }
    ],
    "name": "setFaucetLimit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "dripAmount",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "faucetLimit",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

async function main() {
  if (!CONFIG.contractAddress) {
    throw new Error("Please set the contract address in the CONFIG object");
  }

  console.log(`\nConfiguring CoinFaucet on ${CONFIG.networkName}...`);
  console.log(`Contract address: ${CONFIG.contractAddress}`);
  
  // Setup provider and wallet
  const provider = new ethers.providers.JsonRpcProvider(
    CONFIG.rpcUrl,
    {
      name: CONFIG.networkName,
      chainId: CONFIG.chainId
    }
  );
  
  // Get wallet from private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Private key not found in environment variables. Please set PRIVATE_KEY in your .env file.");
  }
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log(`Using wallet: ${wallet.address}`);
  
  // Create contract instance
  const contract = new ethers.Contract(CONFIG.contractAddress, CONTRACT_ABI, wallet);
  
  try {
    // Get current values
    const currentDripAmount = await contract.dripAmount();
    const currentFaucetLimit = await contract.faucetLimit();
    
    console.log(`\nCurrent settings:`);
    console.log(`- Drip Amount: ${ethers.utils.formatEther(currentDripAmount)} AVAX`);
    console.log(`- Faucet Limit: ${ethers.utils.formatEther(currentFaucetLimit)} AVAX`);
    
    // Set new drip amount
    console.log(`\nSetting new drip amount to ${CONFIG.dripAmount} AVAX...`);
    const dripTx = await contract.setDripAmount(
      ethers.utils.parseEther(CONFIG.dripAmount)
    );
    console.log(`Transaction hash: ${dripTx.hash}`);
    await dripTx.wait();
    console.log(`Drip amount set successfully!`);
    
    // Set new faucet limit
    console.log(`\nSetting new faucet limit to ${CONFIG.faucetLimit} AVAX...`);
    const limitTx = await contract.setFaucetLimit(
      ethers.utils.parseEther(CONFIG.faucetLimit)
    );
    console.log(`Transaction hash: ${limitTx.hash}`);
    await limitTx.wait();
    console.log(`Faucet limit set successfully!`);
    
    // Verify new values
    const newDripAmount = await contract.dripAmount();
    const newFaucetLimit = await contract.faucetLimit();
    
    console.log(`\nNew settings:`);
    console.log(`- Drip Amount: ${ethers.utils.formatEther(newDripAmount)} AVAX`);
    console.log(`- Faucet Limit: ${ethers.utils.formatEther(newFaucetLimit)} AVAX`);
    
    console.log(`\nConfiguration complete!`);
    console.log(`Explorer: https://explorer.ulalo.xyz/address/${CONFIG.contractAddress}`);
  } catch (error) {
    console.error(`\nError: ${error.message}`);
    
    if (error.message.includes("Not the manager")) {
      console.error(`This wallet doesn't have manager rights to the contract.`);
      console.error(`Only the contract manager can change these settings.`);
    }
    
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });