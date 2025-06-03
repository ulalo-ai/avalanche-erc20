const { ethers } = require("ethers");
require("dotenv").config();

async function main() {
  console.log("📝 Starting deployment for Ulalo Bridge components");
  console.log("==============================================");

  // Connect to Ulalo Network
  const provider = new ethers.providers.JsonRpcProvider("https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc");
  
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
  const balanceInUla = ethers.utils.formatEther(balance);
  console.log(`💰 Deployer balance: ${balanceInUla} ULA`);
  
  if (balance.lt(ethers.utils.parseEther("0.1"))) {
    console.warn("⚠️  WARNING: Low balance for deployment. Recommended at least 0.1 ULA");
  }

  // Get network details for confirmation
  const network = await provider.getNetwork();
  console.log(`🌐 Connected to network: Chain ID ${network.chainId}`);

  try {
    // 1. Deploy UlaloWrappedTokenMinter contract
    console.log("\n🚀 Deploying UlaloWrappedTokenMinter...");
    const UlaloWrappedTokenMinterArtifact = require("../out/UlaloNetworkBridge.sol/UlaloWrappedTokenMinter.json");
    const UlaloMinterFactory = new ethers.ContractFactory(
      UlaloWrappedTokenMinterArtifact.abi,
      UlaloWrappedTokenMinterArtifact.bytecode,
      wallet
    );
    
    const minter = await UlaloMinterFactory.deploy();
    console.log(`⏳ Waiting for deployment transaction: ${minter.deployTransaction.hash}`);
    await minter.deployed();
    console.log(`✅ UlaloWrappedTokenMinter deployed at: ${minter.address}`);

    // 2. Deploy wrapped AVAX token
    console.log("\n🚀 Deploying wrapped AVAX token (wAVAX)...");
    const WrappedAVAXArtifact = require("../out/wAVAX.sol/WAVAX.json");
    const WAVAXFactory = new ethers.ContractFactory(
      WrappedAVAXArtifact.abi,
      WrappedAVAXArtifact.bytecode, 
      wallet
    );
    
    const wAVAX = await WAVAXFactory.deploy(wallet.address);
    console.log(`⏳ Waiting for deployment transaction: ${wAVAX.deployTransaction.hash}`);
    await wAVAX.deployed();
    console.log(`✅ wAVAX token deployed at: ${wAVAX.address}`);

    // 3. Configure the bridge
    console.log("\n⚙️ Configuring bridge and tokens...");
    
    // Add bridge address to wAVAX
    let tx = await wAVAX.addBridge(minter.address);
    await tx.wait();
    console.log(`✅ Added minter as bridge for wAVAX`);
    
    // Set wAVAX as native coin wrapped token in bridge
    tx = await minter.setNativeCoinWrapped(wAVAX.address);
    await tx.wait();
    console.log(`✅ Set wAVAX as the native coin wrapped token in UlaloWrappedTokenMinter`);

    // Log deployment summary
    console.log("\n📋 Deployment Summary");
    console.log("==============================================");
    console.log(`Network:                 Ulalo Network (Chain ID: ${network.chainId})`);
    console.log(`RPC:                     https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc`);
    console.log(`UlaloWrappedTokenMinter: ${minter.address}`);
    console.log(`wAVAX token:             ${wAVAX.address}`);
    console.log(`Admin:                   ${wallet.address}`);
    console.log("==============================================");
    console.log("\n🔗 Next Steps:");
    console.log("1. Set up a relayer to monitor NativeCoinLocked events on Fuji and call mintNativeCoinWrapped on Ulalo");
    console.log("2. Set up a relayer to monitor AVAX burn events on Ulalo and call unlockNativeCoin on Fuji");
    console.log("==============================================");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error in script:", error);
    process.exit(1);
  });