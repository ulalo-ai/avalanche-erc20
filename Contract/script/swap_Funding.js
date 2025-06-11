const { ethers } = require('ethers');
require('dotenv').config();

// Network Configuration
const NETWORK_CONFIG = {
  name: "Ulalo Network",
  chainId: 237776,
  rpc: "https://rpc.ulalo.xyz/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
};

// Contract Addresses
const WAVAX_ADDRESS = "0x8f4eC963Def883487fAC91Ff6B137680Ec7F6c04";
const ROUTER_ADDRESS = "0xfb8224b17c0BD9095134027f4e663416b43775ae";

// Amounts (maintain the ratio if pool exists)
const WAVAX_AMOUNT_FIRST = ethers.utils.parseEther("989.5");  // Half of 1979 WAVAX
const WAVAX_AMOUNT_SECOND = ethers.utils.parseEther("989.5"); // Other half
const ULA_AMOUNT = ethers.utils.parseEther("48966"); // Total ULA amount

// Updated ABIs
const WAVAX_ABI = [
  "function mint(address to, uint256 amount) external",
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)"
];

const ROUTER_ABI = [
  "function addLiquidityWithWAVAX(uint256 amountWAVAX) external payable",
  "function reserveULA() external view returns (uint256)",
  "function reserveWAVAX() external view returns (uint256)",
  "function setStrictBalanceCheck(bool _enabled) external",
  "function strictBalanceCheckEnabled() external view returns (bool)"
];

// Add amount validation
const validateAmounts = async (wallet, wavax, totalWavax, totalUla) => {
  const wavaxBalance = await wavax.balanceOf(wallet.address);
  const ulaBalance = await wallet.provider.getBalance(wallet.address);
  
  console.log("\n--- Current Balances ---");
  console.log(`WAVAX: ${ethers.utils.formatEther(wavaxBalance)} WAVAX`);
  console.log(`ULA: ${ethers.utils.formatEther(ulaBalance)} ULA`);
  
  console.log("\n--- Required Amounts ---");
  console.log(`WAVAX: ${ethers.utils.formatEther(totalWavax)} WAVAX`);
  console.log(`ULA: ${ethers.utils.formatEther(totalUla)} ULA (plus gas)`);

  // Check if WAVAX minting is needed
  if (wavaxBalance.lt(totalWavax)) {
    const neededAmount = totalWavax.sub(wavaxBalance);
    console.log(`\n🔨 Minting additional ${ethers.utils.formatEther(neededAmount)} WAVAX...`);
    const mintTx = await wavax.mint(wallet.address, neededAmount);
    await mintTx.wait();
    console.log("✅ WAVAX minted successfully");
  }
  
  // Validate ULA balance
  if (ulaBalance.lt(totalUla.add(ethers.utils.parseEther("0.1")))) {
    throw new Error(`Insufficient ULA balance. Need ${ethers.utils.formatEther(totalUla)} plus gas`);
  }
};

async function main() {
    try {
        const wallet = getWallet();
        
        // Add network check
        const isConnected = await checkNetwork(wallet.provider);
        if (!isConnected) {
            throw new Error("Failed to connect to network");
        }
        
        console.log(`Connected with address: ${wallet.address}`);

    // Connect to contracts
    const wavax = new ethers.Contract(WAVAX_ADDRESS, WAVAX_ABI, wallet);
    const router = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, wallet);

    // Check network
    await checkNetwork(wallet.provider);

    // Validate balances before proceeding
    const totalWavaxNeeded = WAVAX_AMOUNT_FIRST.add(WAVAX_AMOUNT_SECOND);
    await validateAmounts(wallet, wavax, totalWavaxNeeded, ULA_AMOUNT);

    // Step 1: Mint total WAVAX needed
    console.log("\n🔨 Minting WAVAX...");
    const mintTx = await wavax.mint(wallet.address, totalWavaxNeeded);
    console.log(`Mint TX: ${mintTx.hash}`);
    await mintTx.wait();

    // Step 2: Approve WAVAX for total amount
    console.log("\n🔑 Approving WAVAX...");
    const approveTx = await wavax.approve(ROUTER_ADDRESS, totalWavaxNeeded);
    console.log(`Approve TX: ${approveTx.hash}`);
    await approveTx.wait();

    // Verify approvals
    const allowance = await wavax.allowance(wallet.address, ROUTER_ADDRESS);
    console.log(`WAVAX Allowance: ${ethers.utils.formatEther(allowance)}`);

    // Disable strict balance check if needed
    const isStrict = await router.strictBalanceCheckEnabled();
    if (isStrict) {
      console.log("\n🔄 Disabling strict balance check...");
      const disableTx = await router.setStrictBalanceCheck(false);
      await disableTx.wait();
      console.log("✅ Strict balance check disabled");
    }

    // Step 3: Add first liquidity pair (WAVAX-ULA)
    console.log("\n💧 Adding first liquidity pair (WAVAX-ULA)...");
    const addFirstLiquidityTx = await router.addLiquidityWithWAVAX(
      WAVAX_AMOUNT_FIRST,
      {
        value: ULA_AMOUNT.div(2), // 24483 ULA
        gasLimit: 5000000,
        gasPrice: await wallet.provider.getGasPrice()
      }
    );
    console.log(`First Pair TX: ${addFirstLiquidityTx.hash}`);
    await addFirstLiquidityTx.wait();

    // Step 4: Add second liquidity pair (WAVAX-ULA)
    console.log("\n💧 Adding second liquidity pair (WAVAX-ULA)...");
    const addSecondLiquidityTx = await router.addLiquidityWithWAVAX(
      WAVAX_AMOUNT_SECOND,
      {
        value: ULA_AMOUNT.div(2), // 24483 ULA
        gasLimit: 5000000,
        gasPrice: await wallet.provider.getGasPrice()
      }
    );
    console.log(`Second Pair TX: ${addSecondLiquidityTx.hash}`);
    await addSecondLiquidityTx.wait();

    // Verify final balances
    const finalWavaxBalance = await wavax.balanceOf(wallet.address);
    const finalUlaBalance = await wallet.provider.getBalance(wallet.address);
    
    console.log("\n--- Final Balances ---");
    console.log(`WAVAX: ${ethers.utils.formatEther(finalWavaxBalance)} WAVAX`);
    console.log(`ULA: ${ethers.utils.formatEther(finalUlaBalance)} ULA`);
    
    console.log("\n🎉 Liquidity successfully added for both pairs!");
    
  } catch (error) {
    console.error("\n❌ Error:", error);
    if (error.reason) console.error("Reason:", error.reason);
    process.exit(1);
  }
}

function getWallet() {
    if (!process.env.PRIVATE_KEY) {
        throw new Error("Missing PRIVATE_KEY in .env file");
    }
    
    const provider = new ethers.providers.JsonRpcProvider(NETWORK_CONFIG.rpc, {
        name: NETWORK_CONFIG.name,
        chainId: NETWORK_CONFIG.chainId,
        timeout: 30000, // 30 seconds timeout
        headers: {
            "Content-Type": "application/json"
        }
    });
    
    // Add connection retry logic
    provider.on("error", (error) => {
        console.error("Provider error:", error);
    });
    
    return new ethers.Wallet(process.env.PRIVATE_KEY, provider);
}

async function checkNetwork(provider) {
    try {
        await provider.ready; // Wait for provider to be ready
        const network = await provider.getNetwork();
        
        if (network.chainId !== NETWORK_CONFIG.chainId) {
            throw new Error(`Wrong network. Expected chainId: ${NETWORK_CONFIG.chainId}, got: ${network.chainId}`);
        }
        
        console.log(`Connected to network: ${network.name} (chainId: ${network.chainId})`);
        return true;
    } catch (error) {
        console.error("Network connection failed:", error.message);
        console.error("Please check if:");
        console.error("1. The RPC endpoint is correct");
        console.error("2. Your internet connection is stable");
        console.error("3. The network is operational");
        return false;
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("Script failed:", error);
    process.exit(1);
  });