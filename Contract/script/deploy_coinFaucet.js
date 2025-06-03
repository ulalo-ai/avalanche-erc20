const { ethers } = require('ethers');
const fs = require('fs');
require('dotenv').config();

async function main() {
  console.log("Deploying CoinFaucet to Ulalo Network...");
  
  // Create provider using the given RPC URL
  const provider = new ethers.providers.JsonRpcProvider(
    "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
    {
      name: "Fuji Testnet",
      chainId: 237776
    }
  );

  // Get wallet from private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Private key not found in environment variables");
  }
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log("Deployer address:", wallet.address);

  // Get contract artifacts for CoinFaucet
  const contractPath = "./artifacts/src/coinfaucet.sol/CoinFaucet.json";
  if (!fs.existsSync(contractPath)) {
    console.log("Contract artifact not found. Compiling...");
    const { execSync } = require('child_process');
    execSync('npx hardhat compile', { stdio: 'inherit' });
  }
  const contractJson = JSON.parse(fs.readFileSync(contractPath));
  
  // Deploy CoinFaucet
  console.log("Deploying CoinFaucet...");
  const factory = new ethers.ContractFactory(
    contractJson.abi, 
    contractJson.bytecode, 
    wallet
  );
  
  const faucet = await factory.deploy();
  await faucet.deployed();
  console.log("CoinFaucet deployed to:", faucet.address);
  
  // Fund the faucet with 1 coin
  console.log("Funding faucet with 1 coin...");
  const fundTx = await wallet.sendTransaction({
    to: faucet.address,
    value: ethers.utils.parseEther("1.0")
  });
  console.log("Funding transaction:", fundTx.hash);
  await fundTx.wait();
  console.log("Funding complete!");
  
  // Set faucet limit
  console.log("Setting faucet limit...");
  const limitTx = await faucet.setFaucetLimit(ethers.utils.parseEther("1.0"));
  await limitTx.wait();
  console.log("Faucet limit set to 1 coin");
  
  // Verify contract (if needed)
  console.log("\nTo verify this contract:");
  console.log(`forge verify-contract \\
  --chain 237776 \\
  --compiler-version 0.8.20 \\
  --watch \\
  --constructor-args $(cast abi-encode "constructor()") \\
  ${faucet.address} \\
  src/coinfaucet.sol:CoinFaucet \\
  --verifier blockscout \\
  --verifier-url "https://explorer.ulalo.xyz/api"`);
  
  // Save deployment info
  const deploymentInfo = {
    network: "Ulalo",
    chainId: 237776,
    contractAddress: faucet.address,
    deployer: wallet.address,
    fundAmount: "1.0 AVAX",
    deploymentTimestamp: new Date().toISOString()
  };
  
  fs.writeFileSync(
    'coinfaucet-deployment.json', 
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\nDeployment info saved to coinfaucet-deployment.json");
  
  console.log("\nDeployment complete!");
  console.log(`CoinFaucet: ${faucet.address}`);
  console.log(`Explorer: https://explorer.ulalo.xyz/address/${faucet.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });