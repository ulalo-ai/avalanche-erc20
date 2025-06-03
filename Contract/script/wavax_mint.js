const { ethers } = require('ethers');
require('dotenv').config();

// Configuration
const NETWORK_CONFIG = {
  name: "Ulalo Network",
  chainId: 237776,
  rpc: "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
};

// Fixed addresses
const DEPLOYER_ADDRESS = "0xA8F678cF2311e8575cd8b51E709e0B234896d75F";
const WAVAX_TOKEN_ADDRESS = "0x8f4eC963Def883487fAC91Ff6B137680Ec7F6c04";
const ULALO_SWAP_ADDRESS = "0xfb8224b17c0BD9095134027f4e663416b43775ae";

// Amount to mint
const MINT_AMOUNT = ethers.utils.parseEther("100"); // 100 wAVAX tokens
const LIQUIDITY_ULA = ethers.utils.parseEther("1"); 
const LIQUIDITY_WAVAX = ethers.utils.parseEther("50");

// Helper function to get wallet
function getWallet() {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("Missing PRIVATE_KEY in .env file");
  }
  
  const provider = new ethers.providers.JsonRpcProvider(NETWORK_CONFIG.rpc);
  return new ethers.Wallet(process.env.PRIVATE_KEY, provider);
}

// WAVAX ABI - includes functions we need from the token contract
const WAVAX_ABI = [
  "function addBridge(address bridgeAddress) external",
  "function mint(address to, uint256 amount) external",
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function hasRole(bytes32 role, address account) external view returns (bool)"
];

// UlaloSwap minimal ABI
const SWAP_ABI = [
  "function addLiquidityWithULA(uint amountWAVAX) external payable",
  "function addLiquidityWithWAVAX(uint amountWAVAX) external payable", // Add this
  "function reserveULA() external view returns (uint256)",
  "function reserveWAVAX() external view returns (uint256)"
];

async function main() {
  try {
    console.log("🚀 Starting wAVAX bridge setup and minting process");
    
    // Connect to wallet
    const wallet = getWallet();
    console.log(`Connected with address: ${wallet.address}`);
    
    // Verify wallet is the expected one
    if (wallet.address.toLowerCase() !== DEPLOYER_ADDRESS.toLowerCase()) {
      console.warn(`⚠️  Warning: Connected with ${wallet.address} but expected ${DEPLOYER_ADDRESS}`);
    }
    
    // Check ULA balance
    const ulaBalance = await wallet.provider.getBalance(wallet.address);
    console.log(`ULA Balance: ${ethers.utils.formatEther(ulaBalance)} ULA`);
    
    // Connect to WAVAX contract
    const wavaxToken = new ethers.Contract(
      WAVAX_TOKEN_ADDRESS,
      WAVAX_ABI,
      wallet
    );
    
    // Check if deployer already has BRIDGE_ROLE
    const BRIDGE_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("BRIDGE_ROLE"));
    const hasBridgeRole = await wavaxToken.hasRole(BRIDGE_ROLE, wallet.address);
    
    if (hasBridgeRole) {
      console.log("✅ Address already has BRIDGE_ROLE");
    } else {
      console.log("🔑 Adding BRIDGE_ROLE to your address...");
      const addBridgeTx = await wavaxToken.addBridge(wallet.address);
      console.log(`Transaction hash: ${addBridgeTx.hash}`);
      await addBridgeTx.wait();
      console.log("✅ BRIDGE_ROLE added successfully");
    }
    
    // Check current wAVAX balance
    const initialBalance = await wavaxToken.balanceOf(wallet.address);
    console.log(`Current wAVAX balance: ${ethers.utils.formatEther(initialBalance)} wAVAX`);
    
    // Mint wAVAX tokens if needed
    if (initialBalance.lt(LIQUIDITY_WAVAX)) {
      console.log(`Minting ${ethers.utils.formatEther(MINT_AMOUNT)} wAVAX tokens...`);
      const mintTx = await wavaxToken.mint(wallet.address, MINT_AMOUNT);
      console.log(`Transaction hash: ${mintTx.hash}`);
      await mintTx.wait();
      
      // Verify new balance
      const newBalance = await wavaxToken.balanceOf(wallet.address);
      console.log(`New wAVAX balance: ${ethers.utils.formatEther(newBalance)} wAVAX`);
    }
    
    // Connect to UlaloSwap contract 
    const swapContract = new ethers.Contract(
      ULALO_SWAP_ADDRESS, 
      SWAP_ABI,
      wallet
    );
    
    // Get current reserves
    const reserveUlaBefore = await swapContract.reserveULA();
    const reserveWavaxBefore = await swapContract.reserveWAVAX();
    console.log("\n--- Current Swap Reserves ---");
    console.log(`ULA: ${ethers.utils.formatEther(reserveUlaBefore)} ULA`);
    console.log(`wAVAX: ${ethers.utils.formatEther(reserveWavaxBefore)} wAVAX`);
    
    // If reserves are already set, skip adding liquidity
    if (!reserveUlaBefore.isZero() && !reserveWavaxBefore.isZero()) {
      console.log("⚠️  Liquidity pool already has tokens, skipping liquidity addition");
      return;
    }
    
    // Add liquidity to the swap contract
    console.log(`\n💧 Adding liquidity: ${ethers.utils.formatEther(LIQUIDITY_ULA)} ULA and ${ethers.utils.formatEther(LIQUIDITY_WAVAX)} wAVAX`);
    
    // First approve wAVAX tokens for the swap contract
    console.log("Approving wAVAX tokens for swap contract...");
    const approveTx = await wavaxToken.approve(ULALO_SWAP_ADDRESS, LIQUIDITY_WAVAX);
    console.log(`Transaction hash: ${approveTx.hash}`);
    await approveTx.wait();
    console.log("✅ wAVAX tokens approved");
    
    // Add liquidity
    console.log("Adding liquidity to swap contract...");
    const addLiquidityTx = await swapContract.addLiquidityWithWAVAX(LIQUIDITY_ULA, {
      value: LIQUIDITY_WAVAX,
      gasLimit: 5000000
    });
    console.log(`Transaction hash: ${addLiquidityTx.hash}`);
    await addLiquidityTx.wait();
    console.log("✅ Liquidity added successfully!");
    
    // Verify new reserves
    const reserveUlaAfter = await swapContract.reserveULA();
    const reserveWavaxAfter = await swapContract.reserveWAVAX();
    console.log("\n--- Updated Swap Reserves ---");
    console.log(`ULA: ${ethers.utils.formatEther(reserveUlaAfter)} ULA`);
    console.log(`wAVAX: ${ethers.utils.formatEther(reserveWavaxAfter)} wAVAX`);
    
    console.log("\n🎉 Process completed successfully!");
  } catch (error) {
    console.error("❌ Error:", error);
    
    // Try to provide more helpful error messages
    if (error.reason) {
      console.error("Reason:", error.reason);
    }
    if (error.data) {
      console.error("Error data:", error.data);
    }
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Script failed:", error);
    process.exit(1);
  });