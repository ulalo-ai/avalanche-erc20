const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

function getWallet(network = "fuji") {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Private key not found in environment variables");
  }

  let provider;
  switch (network) {
    case "fuji":
      provider = new ethers.providers.JsonRpcProvider(
        process.env.RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
        {
          name: "avalanche-fuji",
          chainId: 43113
        }
      );
      break;
    default:
      throw new Error(`Unsupported network: ${network}`);
  }

  return new ethers.Wallet(privateKey, provider);
}

async function deployContract(contractName, artifactName, constructorArgs = [], network = "fuji") {
  console.log(`Deploying ${contractName} to Avalanche Fuji C-Chain...`);
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
