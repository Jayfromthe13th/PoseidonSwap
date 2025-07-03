require("@nomicfoundation/hardhat-toolbox");
require("@moved/hardhat-plugin");

module.exports = {
  defaultNetwork: "devnet",
  networks: {
    devnet: {
      url: "https://devnet.uminetwork.com",
      accounts: ["YOUR_PRIVATE_KEY"] // Replace this with your actual private key
    }
  }
}; 