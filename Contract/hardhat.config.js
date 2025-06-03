// filepath: /Users/wolfedgelabs/Ulao_SC/Contract/hardhat.config.js
require('@nomicfoundation/hardhat-toolbox');
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    ulalo: {
      url: "https://rpc.ulalo.xyz/34CjKI4QNj4VJKuT12/ext/bc/WxJtVSojQ1LpPguqJCq45NZutD8T8aZpnnAZTZyfPkNKrsjye/rpc",
      chainId: 237776,
      accounts: [process.env.PRIVATE_KEY]
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      // For Fuji verification
      avalancheFujiTestnet: "api",
      // For Ulalo verification (using a custom explorer)
      ulalo: "api" 
    },
    customChains: [
      {
        network: "ulalo",
        chainId: 237776,
        urls: {
          apiURL: "https://explorer.ulalo.xyz/api?module=contract&action=verify",
          browserURL: "https://explorer.ulalo.xyz"
        }
      }
    ]
  },
  paths: {
    sources: "./src",  // Tell Hardhat to look for contracts in the src directory
  }
};
