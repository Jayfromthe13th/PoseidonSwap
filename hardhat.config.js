require("@nomicfoundation/hardhat-toolbox");
require("@moved/hardhat-plugin");

// For deployment, you'll need to replace this with your actual private key
// You can also use environment variables: process.env.PRIVATE_KEY
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x080d4ed41915ecff60cc353f79a82b12b05a65f89ba69527b27cfbc957962f55";

module.exports = {
  defaultNetwork: "devnet",
  networks: {
    devnet: {
      url: "https://devnet.uminetwork.com",
      accounts: [PRIVATE_KEY],
    }
  }
}; 