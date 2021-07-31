const configuration = {
    contracts_build_directory: "build",
    compilers: {
        solc: {
            version: "^0.8.0",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200,
                },
            },
        },
    },
    plugins: ["solidity-coverage"],

 networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 1000,
      gas: 4612388,
      gasPrice: 25000000000,
      total_accounts: 20,
    } }

};
if (process.argv.indexOf("--gas-report") >= 0) {
    configuration.mocha = {
        reporter: "eth-gas-reporter",
        reporterOptions: {
            currency: "USD",
            excludeContracts: ["test/TestDependencies.sol"],
        },
    };
}

module.exports = configuration;
