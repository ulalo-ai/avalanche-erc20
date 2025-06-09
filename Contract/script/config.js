const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// In script/config.js
const networks = {
  ulalo: {
    url: process.env.RPC_URL,
    chainId: parseInt(process.env.CHAIN_ID),
    accounts: [process.env.PRIVATE_KEY]
  },
  // ... other networks
};

function getWallet(network = "ulalo") {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Private key not found in environment variables");
  }

  let provider;
  switch (network) {
    case "ulalo":
      provider = new ethers.providers.JsonRpcProvider(
        "https://rpc-ulalo.cogitus.io/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
        {
          name: "Fuji Testnet",
          chainId: 237776
        }
      );
      break;
    default:
      throw new Error(`Unsupported network: ${network}`);
  }

  return new ethers.Wallet(privateKey, provider);
}

// Update the deployContract function to show correct network in logs
async function deployContract(contractName, artifactName, constructorArgs = [], network = "ulalo") {
  console.log(`Deploying ${contractName} to ${network.charAt(0).toUpperCase() + network.slice(1)} Network...`);
  const wallet = getWallet(network);
  console.log("Deployer address:", wallet.address);

  // Adjusted path pattern to match Foundry's output structure
  let artifactPath;
  if (fs.existsSync(`./out/${artifactName}.sol/${artifactName}.json`)) {
    artifactPath = path.join(__dirname, `../out/${artifactName}.sol/${artifactName}.json`);
  } else {
    artifactPath = path.join(__dirname, `../out/${artifactName}.json`);
  }
  
  const artifact = require(artifactPath);
  
  const factory = new ethers.ContractFactory(
    artifact.abi,
    artifact.bytecode,
    wallet
  );

  const contract = await factory.deploy(...constructorArgs);
  await contract.deployed();
  console.log(`${contractName} deployed to:`, contract.address);
  return contract;
}

async function saveDeploymentAddress(key, address) {
  const deploymentDir = "./deployments";
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir);
  }
  
  const filePath = `${deploymentDir}/addresses.json`;
  let addresses = {};
  
  if (fs.existsSync(filePath)) {
    const data = fs.readFileSync(filePath);
    addresses = JSON.parse(data);
  }
  
  addresses[key] = address;
  fs.writeFileSync(filePath, JSON.stringify(addresses, null, 2));
  console.log(`Saved ${key} address: ${address}`);
}

async function getDeploymentAddress(key) {
  const filePath = "./deployments/addresses.json";
  if (!fs.existsSync(filePath)) {
    throw new Error("No deployments found");
  }
  
  const data = fs.readFileSync(filePath);
  const addresses = JSON.parse(data);
  
  if (!addresses[key]) {
    throw new Error(`Address for ${key} not found`);
  }
  
  return addresses[key];
}

module.exports = {
  getWallet,
  deployContract,
  saveDeploymentAddress,
  getDeploymentAddress
};
