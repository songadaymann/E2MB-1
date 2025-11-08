require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
            optimizerSteps: "dhfoDgvulfnTUtnIf"
          }
        }
      },
      viaIR: true
    }
  },
  paths: {
    sources: "./src",
    tests: "./hardhat-tests",
    cache: "./cache-hardhat",
    artifacts: "./artifacts"
  },
  networks: {
    hardhat: {
      gas: 30000000,
      blockGasLimit: 30000000
    }
  }
};
