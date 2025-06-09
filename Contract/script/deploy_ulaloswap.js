// script/deploy_ulaloswap.js
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Configuration for Ulalo Network
const NETWORK_CONFIG = {
  name: "Ulalo Network",
  chainId: 237776,
  rpc: "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
};

// Fixed addresses
const DEPLOYER_ADDRESS = "0xA8F678cF2311e8575cd8b51E709e0B234896d75F";
const WAVAX_TOKEN_ADDRESS = "0x8f4eC963Def883487fAC91Ff6B137680Ec7F6c04";

// Helper function to get wallet
function getWallet() {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("Missing PRIVATE_KEY in .env file");
  }
  
  const provider = new ethers.providers.JsonRpcProvider(NETWORK_CONFIG.rpc);
  return new ethers.Wallet(process.env.PRIVATE_KEY, provider);
}

// Helper function to deploy contract
async function deployContract(contractName, args) {
  const wallet = getWallet();
  
  // Read the contract artifact
  const artifactPath = path.resolve(__dirname, `../out/${contractName}.sol/${contractName}.json`);
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  
  // Create a ContractFactory
  const factory = new ethers.ContractFactory(
    artifact.abi,
    artifact.bytecode,
    wallet
  );
  
  // Deploy the contract
  console.log(`Deploying ${contractName}...`);
  const contract = await factory.deploy(...args);
  
  console.log(`Transaction hash: ${contract.deployTransaction.hash}`);
  await contract.deployed();
  console.log(`${contractName} deployed at: ${contract.address}`);
  
  return contract;
}

async function main() {
  console.log(`Deploying UlaloSwap to ${NETWORK_CONFIG.name}...`);
  const wallet = getWallet();
  console.log("Deployer address:", wallet.address);
  
  // Verify deployer address matches expected address
  if (wallet.address.toLowerCase() !== DEPLOYER_ADDRESS.toLowerCase()) {
    console.warn(`⚠️ Warning: Deployer address ${wallet.address} does not match expected address ${DEPLOYER_ADDRESS}`);
    // You might want to add a prompt here to confirm continuation
  }
  
  // Verify we're on the right network
  const provider = wallet.provider;
  const network = await provider.getNetwork();
  console.log(`Connected to network with chainId: ${network.chainId}`);
  
  if (network.chainId !== NETWORK_CONFIG.chainId) {
    console.warn(`⚠️ Warning: Connected to chainId ${network.chainId} but expected ${NETWORK_CONFIG.chainId}`);
    // You might want to add a prompt here to confirm continuation
  }
  
  // Check balance before proceeding
  const balance = await wallet.getBalance();
  console.log(`Deployer ULA balance: ${ethers.utils.formatEther(balance)} ULA`);
  
  if (balance.lt(ethers.utils.parseEther("1"))) {
    throw new Error("Insufficient ULA balance for deployment and adding liquidity. Need at least 1 ULA.");
  }
  
  // Using wAVAX token address
  console.log(`Using wAVAX token: ${WAVAX_TOKEN_ADDRESS}`);
  
  // Deploy UlaloSwap
  const swap = await deployContract(
    "UlaloSwap",
    [WAVAX_TOKEN_ADDRESS, wallet.address]
  );
  
  console.log("UlaloSwap deployed to:", swap.address);
  
  // Add initial liquidity
  console.log("Setting up initial liquidity...");
  
  // Load wAVAX token ABI - minimal ABI for ERC20
  const wavaxTokenAbi = [
    "function balanceOf(address account) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transfer(address to, uint256 amount) external returns (bool)"
  ];
  
  // Get wAVAX token contract
  const wavaxToken = new ethers.Contract(
    WAVAX_TOKEN_ADDRESS,
    wavaxTokenAbi,
    wallet
  );
  
  // Initial liquidity amounts
  const initialUla = ethers.utils.parseEther("1"); // 0.1 ULA tokens
  const initialWavax = ethers.utils.parseEther("50"); // 50 wAVAX tokens
  
  console.log(`Adding initial liquidity: ${ethers.utils.formatEther(initialUla)} ULA and ${ethers.utils.formatEther(initialWavax)} wAVAX`);
  
  // Check deployer's wAVAX balance
  const wavaxBalance = await wavaxToken.balanceOf(wallet.address);
  console.log(`Current wAVAX balance: ${ethers.utils.formatEther(wavaxBalance)} wAVAX`);
  
  if (wavaxBalance.lt(initialWavax)) {
    throw new Error(`Insufficient wAVAX balance. Need at least ${ethers.utils.formatEther(initialWavax)} wAVAX`);
  }
  
  // Check ULA balance again to ensure we have enough for liquidity
  const ulaBalance = await wallet.getBalance();
  if (ulaBalance.lt(initialUla.add(ethers.utils.parseEther("0.1")))) {
    throw new Error(`Insufficient ULA balance. Need at least ${ethers.utils.formatEther(initialUla.add(ethers.utils.parseEther("0.1")))} ULA`);
  }
  
  // Approve wAVAX tokens for the swap contract
  console.log("Approving wAVAX tokens for swap contract...");
  const approveTx = await wavaxToken.approve(swap.address, initialWavax);
  console.log(`Approval transaction hash: ${approveTx.hash}`);
  await approveTx.wait();
  console.log("wAVAX tokens approved");
  
  // Load full swap ABI
  const swapArtifactPath = path.resolve(__dirname, '../out/UlaloSwap.sol/UlaloSwap.json');
  let swapAbi;
  
  try {
    const swapArtifact = JSON.parse(fs.readFileSync(swapArtifactPath));
    swapAbi = swapArtifact.abi;
  } catch (err) {
    console.log("Could not read swap artifact, using minimal ABI");
    swapAbi = ["function addLiquidityWithULA(uint amountWAVAX) external payable"];
  }
  
  // Create contract instance with the full ABI
  const swapContract = new ethers.Contract(
    swap.address,
    swapAbi,
    wallet
  );
  
  // Add liquidity
  console.log("Adding initial liquidity...");
  try {
    // Using the correct function name: addLiquidityWithWAVAX which takes ULA as the native token
    const addLiqTx = await swapContract.addLiquidityWithULA(initialWavax, {
      value: initialUla,
      gasLimit: 5000000 // Setting higher gas limit for safety
    });
    
    console.log(`Add liquidity transaction hash: ${addLiqTx.hash}`);
    console.log("Waiting for transaction confirmation...");
    await addLiqTx.wait();
    console.log("Initial liquidity added successfully!");
    
    // Verify liquidity was added correctly
    const reserveUla = await swapContract.reserveULA();
    const reserveWavax = await swapContract.reserveWAVAX();
    
    console.log(`Reserve ULA: ${ethers.utils.formatEther(reserveUla)} ULA`);
    console.log(`Reserve wAVAX: ${ethers.utils.formatEther(reserveWavax)} wAVAX`);
    
  } catch (error) {
    console.error("Failed to add liquidity:", error);
    if (error.data) {
      // Try to decode the error data
      try {
        const iface = new ethers.utils.Interface([
          "function Error(string)",
          "function Panic(uint256)"
        ]);
        const decodedError = iface.parseError(error.data);
        console.error("Decoded error:", decodedError);
      } catch (e) {
        console.error("Raw error data:", error.data);
      }
    }
    console.log("Continue without adding initial liquidity. You can add it manually later.");
  }
  
  // Save deployment info
  const deploymentInfo = {
    network: NETWORK_CONFIG.name,
    chainId: NETWORK_CONFIG.chainId,
    rpc: NETWORK_CONFIG.rpc,
    wavaxToken: WAVAX_TOKEN_ADDRESS,
    ulaloSwap: swap.address,
    initialLiquidity: {
      ula: ethers.utils.formatEther(initialUla),
      wavax: ethers.utils.formatEther(initialWavax)
    },
    owner: wallet.address,
    deployedAt: new Date().toISOString()
  };
  
  const filename = `ulalo-swap-deployment.json`;
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\nDeployment info saved to ${filename}`);
  
  console.log("\n=== UlaloSwap Deployment Summary ===");
  console.log(`Network: ${NETWORK_CONFIG.name} (ChainId: ${NETWORK_CONFIG.chainId})`);
  console.log(`wAVAX Token: ${WAVAX_TOKEN_ADDRESS}`);
  console.log(`UlaloSwap: ${swap.address}`);
  console.log(`Initial ULA: ${ethers.utils.formatEther(initialUla)} ULA`);
  console.log(`Initial wAVAX: ${ethers.utils.formatEther(initialWavax)} wAVAX`);
  console.log(`Owner: ${wallet.address}`);
  console.log("Deployment complete!");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });