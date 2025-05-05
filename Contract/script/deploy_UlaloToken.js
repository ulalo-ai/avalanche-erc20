// deployUlaloToken.js - Script for deploying only UlaloToken
require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

async function main() {
    console.log("Starting UlaloToken deployment...");

    // Load UlaloToken contract ABI & bytecode
    const artifactPath = path.resolve(__dirname, `../out/UlaloToken.sol/UlaloToken.json`);
    if (!fs.existsSync(artifactPath)) {
        throw new Error(`Artifact for UlaloToken not found at ${artifactPath}. Make sure you've run 'forge build'`);
    }
    
    const artifact = JSON.parse(fs.readFileSync(artifactPath));
    const abi = artifact.abi;
    const bytecode = artifact.bytecode.object;

    // Setup provider and wallet
    const PRIVATE_KEY = process.env.PRIVATE_KEY;
    const RPC_URL = process.env.RPC_URL;
    
    if (!PRIVATE_KEY || !RPC_URL) {
        throw new Error("Missing PRIVATE_KEY or RPC_URL in .env file");
    }

    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const deployer = wallet.address;
    
    console.log(`Deploying from address: ${deployer}`);
    
    // Check wallet balance
    const balance = await provider.getBalance(deployer);
    console.log(`Wallet balance: ${ethers.utils.formatEther(balance)} ETH/AVAX`);
    
    // Network info
    const network = await provider.getNetwork();
    console.log(`Deploying to network: ${network.name} (chainId: ${network.chainId})`);

    // Deploy UlaloToken
    console.log("\nDeploying UlaloToken...");
    const UlaloTokenFactory = new ethers.ContractFactory(abi, bytecode, wallet);
    
    // Get token parameters from env or use defaults
    const TOKEN_NAME = process.env.TOKEN_NAME || "Ulalo Token";
    const TOKEN_SYMBOL = process.env.TOKEN_SYMBOL || "ULA";
    
    const ulaloToken = await UlaloTokenFactory.deploy(
        TOKEN_NAME,
        TOKEN_SYMBOL,
        deployer  // Initial Owner with all roles
    );
    
    console.log(`Transaction hash: ${ulaloToken.deployTransaction.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    await ulaloToken.deployed();
    console.log(`UlaloToken deployed successfully to: ${ulaloToken.address}`);
    
    // Get token details
    const totalSupply = await ulaloToken.totalSupply();
    const formattedSupply = ethers.utils.formatUnits(totalSupply, 18);
    console.log(`Initial token supply: ${formattedSupply} ${TOKEN_SYMBOL}`);
    
    // Optional: Configure token parameters
    if (process.env.TRANSFER_LIMIT_PERCENTAGE) {
        const limit = process.env.TRANSFER_LIMIT_PERCENTAGE;
        console.log(`Setting transfer limit percentage to ${limit}%...`);
        const tx = await ulaloToken.setTransferLimitPercentage(limit);
        await tx.wait();
        console.log("Transfer limit updated");
    }
    
    if (process.env.TRANSFER_COOLDOWN) {
        const cooldown = process.env.TRANSFER_COOLDOWN;
        console.log(`Setting transfer cooldown to ${cooldown} seconds...`);
        const tx = await ulaloToken.setTransferCooldown(cooldown);
        await tx.wait();
        console.log("Transfer cooldown updated");
    }
    
    // Save deployment info
    const deploymentInfo = {
        network: {
            name: network.name,
            chainId: network.chainId.toString()
        },
        token: {
            name: TOKEN_NAME,
            symbol: TOKEN_SYMBOL,
            address: ulaloToken.address,
            totalSupply: formattedSupply,
            decimals: 18
        },
        deployer: deployer,
        timestamp: new Date().toISOString()
    };
    
    const filename = `ulalo-token-deployment-${network.name}.json`;
    fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
    console.log(`\nDeployment info saved to ${filename}`);
    
    console.log("\n=== UlaloToken Deployment Summary ===");
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    console.log(`Token Name: ${TOKEN_NAME}`);
    console.log(`Token Symbol: ${TOKEN_SYMBOL}`);
    console.log(`Token Address: ${ulaloToken.address}`);
    console.log(`Initial Supply: ${formattedSupply} ${TOKEN_SYMBOL}`);
    console.log(`Deployer/Owner: ${deployer}`);
    console.log("================================");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error("Deployment failed:");
        console.error(error);
        process.exit(1);
    });