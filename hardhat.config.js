require("@nomicfoundation/hardhat-toolbox");
require("@moved/hardhat-plugin");

module.exports = {
  defaultNetwork: "devnet",
  networks: {
    devnet: {
      url: "https://devnet.uminetwork.com",
      accounts: ["0xca5ae6a7ac18c3db437de6b3dff8fcf3da06b8fc9432708c71c8d8f8f1185f89"]
    }
  }
};
