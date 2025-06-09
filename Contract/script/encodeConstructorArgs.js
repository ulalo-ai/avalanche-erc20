// scripts/encodeConstructorArgs.js
const { ethers } = require("hardhat");

async function main() {
  const encoded = ethers.utils.defaultAbiCoder.encode(
    ["string", "string", "address"],
    ["Ulalo Token", "ULA", "0xA8F678cF2311e8575cd8b51E709e0B234896d75F"]
  );
  console.log(encoded);
}

main().catch(console.error);