const { ethers } = require('hardhat');
const { AccountAddress, EntryFunction, FixedBytes, parseTypeTag } = require('@aptos-labs/ts-sdk');
const { TransactionPayloadEntryFunction, TypeTagSigner } = require('@aptos-labs/ts-sdk');

async function main() {
  // We'll deploy each contract in sequence
  const contracts = ['apt_token', 'shell_token', 'umi_token', 'lp_token', 'pool'];
  const [deployer] = await ethers.getSigners();
  const moduleAddress = deployer.address.replace('0x', '0x000000000000000000000000');

  for (const contractName of contracts) {
    console.log(`Deploying ${contractName}...`);
    
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await Contract.deploy();
    await contract.waitForDeployment();
    console.log(`${contractName} is deployed to: ${deployer.address}::${contractName}`);

    // Initialize the contract if it has an initialize function
    try {
      const address = AccountAddress.fromString(moduleAddress);
      const addressBytes = [33, 0, ...address.toUint8Array()];
      const signer = new FixedBytes(new Uint8Array(addressBytes));

      const entryFunction = EntryFunction.build(
        `${moduleAddress}::${contractName}`,
        'initialize',
        [], // Use parseTypeTag(..) to get type arg from string if needed
        [signer]
      );
      const transactionPayload = new TransactionPayloadEntryFunction(entryFunction);
      const payload = transactionPayload.bcsToHex();
      const request = {
        to: deployer.address,
        data: payload.toString(),
      };
      await deployer.sendTransaction(request);
      console.log(`${contractName} initialized successfully`);
    } catch (error) {
      console.log(`Note: ${contractName} either doesn't have an initialize function or initialization failed:`, error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  }); 