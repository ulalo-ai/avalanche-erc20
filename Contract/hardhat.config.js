// filepath: /Users/wolfedgelabs/Ulao_SC/Contract/hardhat.config.js
require('@nomicfoundation/hardhat-toolbox');
require("dotenv").config();
// Remove this line: require('@nomicfoundation/hardhat-verify');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  etherscan: {
    apiKey: {
      snowtrace: 'Avalanche Fuji C-Chain', // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: 'Avalanche Fuji C-Chain',
        chainId: 43113,
        urls: {
          apiURL: 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan',
          browserURL: 'https://avalanche.testnet.localhost:8080',
        },
      },
    ],
  },
  networks: {
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
