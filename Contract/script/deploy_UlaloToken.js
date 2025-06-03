// deployUlaloToken.js - Script for deploying only UlaloToken
require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

async function main() {
    console.log("Starting UlaloToken deployment...");

    // Compile the contract first to ensure latest changes
    console.log("Compiling contracts...");
    try {
        const { exec } = require('child_process');
        await new Promise((resolve, reject) => {
            exec('forge build', (error, stdout, stderr) => {
                if (error) {
                    console.error(`Compilation error: ${error.message}`);
                    return reject(error);
                }
                if (stderr) {
                    console.error(`Compilation stderr: ${stderr}`);
                }
                console.log(stdout);
                resolve();
            });
        });
        console.log("Contracts compiled successfully");
    } catch (error) {
        console.error("Error compiling contracts:", error);
        throw new Error("Contract compilation failed");
    }

    // Load UlaloToken contract ABI & bytecode
    const artifactPath = path.resolve(__dirname, `../out/UlaloToken.sol/UlaloToken.json`);
    if (!fs.existsSync(artifactPath)) {
        throw new Error(`Artifact for UlaloToken not found at ${artifactPath}. Make sure you've run 'forge build'`);
    }
    
    const artifact = JSON.parse(fs.readFileSync(artifactPath));
    const abi = artifact.abi;
    const bytecode = artifact.bytecode;

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
    console.log("\nDeploying UlaloToken with cooldown functionality...");
    const UlaloTokenFactory = new ethers.ContractFactory(abi, bytecode, wallet);
    
    // Get token parameters from env or use defaults
    const TOKEN_NAME = process.env.TOKEN_NAME || "Ulalo Token";
    const TOKEN_SYMBOL = process.env.TOKEN_SYMBOL || "ULA";
    
    // Create deployment transaction with higher gas limit
    const deploymentOptions = {
        gasLimit: 5000000, // Set a higher gas limit for deployment
    };
    
    const ulaloToken = await UlaloTokenFactory.deploy(
        TOKEN_NAME,
        TOKEN_SYMBOL,
        deployer,  // Initial Owner with all roles
        deploymentOptions
    );
    
    console.log(`Transaction hash: ${ulaloToken.deployTransaction.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    await ulaloToken.deployed();
    console.log(`UlaloToken deployed successfully to: ${ulaloToken.address}`);
    
    // Get token details
    const totalSupply = await ulaloToken.totalSupply();
    const formattedSupply = ethers.utils.formatUnits(totalSupply, 18);
    console.log(`Initial token supply: ${formattedSupply} ${TOKEN_SYMBOL}`);
    
    // Configure token parameters - set transfer limit to desired percentage
    const TRANSFER_LIMIT_PERCENTAGE = process.env.TRANSFER_LIMIT_PERCENTAGE || 1; // Default 1%
    console.log(`Setting transfer limit percentage to ${TRANSFER_LIMIT_PERCENTAGE}%...`);
    const limitTx = await ulaloToken.setTransferLimitPercentage(TRANSFER_LIMIT_PERCENTAGE);
    await limitTx.wait();
    console.log(`Transfer limit updated to ${TRANSFER_LIMIT_PERCENTAGE}%`);
    
    // Configure cooldown period
    const COOLDOWN_PERIOD = process.env.COOLDOWN_PERIOD || 3600; // Default 1 hour (3600 seconds)
    console.log(`Setting transfer cooldown period to ${COOLDOWN_PERIOD} seconds...`);
    const cooldownTx = await ulaloToken.setTransferCooldown(COOLDOWN_PERIOD);
    await cooldownTx.wait();
    console.log(`Cooldown period updated to ${COOLDOWN_PERIOD} seconds`);
    
    // Verify the contract (optional)
    try {
        console.log("\nVerifying contract on block explorer...");
        const { exec } = require('child_process');
        const verifyCommand = `forge verify-contract ${ulaloToken.address} UlaloToken --chain ${network.chainId} --constructor-args $(cast abi-encode "constructor(string,string,address)" "${TOKEN_NAME}" "${TOKEN_SYMBOL}" "${deployer}") --verifier-url "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan" --etherscan-api-key "api"`;
        
        await new Promise((resolve, reject) => {
            exec(verifyCommand, (error, stdout, stderr) => {
                if (error) {
                    console.warn(`Contract verification error: ${error.message}`);
                    console.warn("You can manually verify the contract later");
                    return resolve();
                }
                console.log(stdout);
                resolve();
            });
        });
    } catch (error) {
        console.warn("Contract verification failed:", error.message);
        console.warn("You can manually verify the contract later");
    }
    
    // Format cooldown period for display
    let cooldownFormatted;
    if (COOLDOWN_PERIOD >= 86400) {
        cooldownFormatted = `${COOLDOWN_PERIOD / 86400} days`;
    } else if (COOLDOWN_PERIOD >= 3600) {
        cooldownFormatted = `${COOLDOWN_PERIOD / 3600} hours`;
    } else if (COOLDOWN_PERIOD >= 60) {
        cooldownFormatted = `${COOLDOWN_PERIOD / 60} minutes`;
    } else {
        cooldownFormatted = `${COOLDOWN_PERIOD} seconds`;
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
            decimals: 18,
            features: {
                transferLimitPercentage: `${TRANSFER_LIMIT_PERCENTAGE}%`,
                cooldown: cooldownFormatted
            }
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
    console.log(`Transfer Limit: ${TRANSFER_LIMIT_PERCENTAGE}%`);
    console.log(`Cooldown: ${cooldownFormatted}`);
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