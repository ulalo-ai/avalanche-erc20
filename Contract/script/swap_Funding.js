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
const ROUTER_ADDRESS = "0xfb8224b17c0BD9095134027f4e663416b43775ae";

// Amounts (maintain the ratio if pool exists)
const WAVAX_AMOUNT = ethers.utils.parseEther("10");
const ULA_AMOUNT = ethers.utils.parseEther("1000"); 

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

async function main() {
  try {
    const wallet = getWallet();
    console.log(`Connected with address: ${wallet.address}`);

    // Connect to contracts
    const wavax = new ethers.Contract(WAVAX_ADDRESS, WAVAX_ABI, wallet);
    const router = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, wallet);

    // Check initial balances
    const initialWavaxBalance = await wavax.balanceOf(wallet.address);
    const initialUlaBalance = await wallet.provider.getBalance(wallet.address);
    
    console.log("\n--- Initial Balances ---");
    console.log(`WAVAX: ${ethers.utils.formatEther(initialWavaxBalance)} WAVAX`);
    console.log(`ULA: ${ethers.utils.formatEther(initialUlaBalance)} ULA`);

    // Check existing pool ratio if exists
    const reserveULA = await router.reserveULA();
    const reserveWAVAX = await router.reserveWAVAX();
    
    if (reserveULA.gt(0) && reserveWAVAX.gt(0)) {
      console.log("\nExisting pool ratio:", ethers.utils.formatEther(reserveULA.mul(ethers.constants.WeiPerEther).div(reserveWAVAX)));
      console.log("Adding ratio:", ethers.utils.formatEther(ULA_AMOUNT.mul(ethers.constants.WeiPerEther).div(WAVAX_AMOUNT)));
    }

    // Step 1: Mint WAVAX
    console.log("\n🔨 Minting WAVAX...");
    const mintTx = await wavax.mint(wallet.address, WAVAX_AMOUNT);
    console.log(`Mint TX: ${mintTx.hash}`);
    await mintTx.wait();

    // Step 2: Approve WAVAX
    console.log("\n🔑 Approving WAVAX...");
    const approveTx = await wavax.approve(ROUTER_ADDRESS, WAVAX_AMOUNT);
    console.log(`Approve TX: ${approveTx.hash}`);
    await approveTx.wait();

    // Verify approvals
    const allowance = await wavax.allowance(wallet.address, ROUTER_ADDRESS);
    console.log(`WAVAX Allowance: ${ethers.utils.formatEther(allowance)}`);

    // Connect to router contract again to check strict balance
    const routerWithStrictCheck = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, wallet);

    // Check if strict balance check is enabled
    const isStrict = await routerWithStrictCheck.strictBalanceCheckEnabled();
    console.log("\n🔍 Strict balance check enabled:", isStrict);

    if (isStrict) {
      console.log("🔄 Disabling strict balance check...");
      const disableTx = await routerWithStrictCheck.setStrictBalanceCheck(false);
      console.log(`Disable TX: ${disableTx.hash}`);
      await disableTx.wait();
      console.log("✅ Strict balance check disabled");
    }

    // Step 3: Add liquidity
    console.log("\n💧 Adding liquidity...");
    const addLiquidityTx = await router.addLiquidityWithWAVAX(
      WAVAX_AMOUNT,
      {
        value: ULA_AMOUNT,
        gasLimit: 5000000,
        gasPrice: await wallet.provider.getGasPrice()
      }
    );
    
    console.log(`Add Liquidity TX: ${addLiquidityTx.hash}`);
    await addLiquidityTx.wait();

    // Verify final balances
    const finalWavaxBalance = await wavax.balanceOf(wallet.address);
    const finalUlaBalance = await wallet.provider.getBalance(wallet.address);
    
    console.log("\n--- Final Balances ---");
    console.log(`WAVAX: ${ethers.utils.formatEther(finalWavaxBalance)} WAVAX`);
    console.log(`ULA: ${ethers.utils.formatEther(finalUlaBalance)} ULA`);
    
    console.log("\n🎉 Liquidity successfully added!");
    
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
  return new ethers.Wallet(
    process.env.PRIVATE_KEY, 
    new ethers.providers.JsonRpcProvider(NETWORK_CONFIG.rpc)
  );
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("Script failed:", error);
    process.exit(1);
  });