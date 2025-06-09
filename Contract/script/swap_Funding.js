const { ethers } = require('ethers');
require('dotenv').config();

// Network Configuration
const NETWORK_CONFIG = {
  name: "Ulalo Network",
  chainId: 237776,
  rpc: "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
};

// Contract Addresses
const WAVAX_ADDRESS = "0x8f4eC963Def883487fAC91Ff6B137680Ec7F6c04";
const ULA_ADDRESS = "YOUR_ULA_ADDRESS";
const ROUTER_ADDRESS = "0xfb8224b17c0BD9095134027f4e663416b43775ae";

// Liquidity Amounts
const WAVAX_AMOUNT = ethers.utils.parseEther("10");
const ULA_AMOUNT = ethers.utils.parseEther("1000");

// ABIs
const WAVAX_ABI = [
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)"
];

const ULA_ABI = [
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)"
];

const ROUTER_ABI = [
  "function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity)"
];

function getWallet() {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("Missing PRIVATE_KEY in .env file");
  }
  const provider = new ethers.providers.JsonRpcProvider(NETWORK_CONFIG.rpc);
  return new ethers.Wallet(process.env.PRIVATE_KEY, provider);
}

async function main() {
  try {
    console.log("🚀 Starting liquidity provision process");
    
    // Connect wallet
    const wallet = getWallet();
    console.log(`Connected with address: ${wallet.address}`);

    // Connect to contracts
    const wavax = new ethers.Contract(WAVAX_ADDRESS, WAVAX_ABI, wallet);
    const ula = new ethers.Contract(ULA_ADDRESS, ULA_ABI, wallet);
    const router = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, wallet);

    // Check balances
    const wavaxBalance = await wavax.balanceOf(wallet.address);
    const ulaBalance = await ula.balanceOf(wallet.address);
    
    console.log("\n--- Current Balances ---");
    console.log(`WAVAX: ${ethers.utils.formatEther(wavaxBalance)} WAVAX`);
    console.log(`ULA: ${ethers.utils.formatEther(ulaBalance)} ULA`);

    // Verify sufficient balances
    if (wavaxBalance.lt(WAVAX_AMOUNT)) {
      throw new Error("Insufficient WAVAX balance");
    }
    if (ulaBalance.lt(ULA_AMOUNT)) {
      throw new Error("Insufficient ULA balance");
    }

    // Approve tokens
    console.log("\n🔑 Approving tokens...");
    
    const wavaxApproval = await wavax.approve(ROUTER_ADDRESS, WAVAX_AMOUNT);
    console.log(`WAVAX Approval TX: ${wavaxApproval.hash}`);
    await wavaxApproval.wait();
    
    const ulaApproval = await ula.approve(ROUTER_ADDRESS, ULA_AMOUNT);
    console.log(`ULA Approval TX: ${ulaApproval.hash}`);
    await ulaApproval.wait();

    // Add liquidity
    console.log("\n💧 Adding liquidity...");
    const addLiquidityTx = await router.addLiquidity(
      WAVAX_ADDRESS,
      ULA_ADDRESS,
      WAVAX_AMOUNT,
      ULA_AMOUNT,
      WAVAX_AMOUNT.mul(99).div(100), // 5% slippage
      ULA_AMOUNT.mul(95).div(100),
      wallet.address,
      Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes deadline
      { gasLimit: 5000000 }
    );
    
    console.log(`Add Liquidity TX: ${addLiquidityTx.hash}`);
    await addLiquidityTx.wait();

    // Verify final balances
    const finalWavaxBalance = await wavax.balanceOf(wallet.address);
    const finalUlaBalance = await ula.balanceOf(wallet.address);
    
    console.log("\n--- Final Balances ---");
    console.log(`WAVAX: ${ethers.utils.formatEther(finalWavaxBalance)} WAVAX`);
    console.log(`ULA: ${ethers.utils.formatEther(finalUlaBalance)} ULA`);
    
    console.log("\n🎉 Liquidity successfully added!");
    
  } catch (error) {
    console.error("❌ Error:", error);
    if (error.reason) console.error("Reason:", error.reason);
    if (error.data) console.error("Error data:", error.data);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Script failed:", error);
    process.exit(1);
  });