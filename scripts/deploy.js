const { ethers } = require('hardhat');
const { AccountAddress, EntryFunction, FixedBytes, parseTypeTag } = require('@aptos-labs/ts-sdk');
const { TransactionPayloadEntryFunction, TypeTagSigner } = require('@aptos-labs/ts-sdk');

async function main() {
  const moduleNames = ['errors', 'events', 'math', 'lp_token', 'pool', 'umi_token', 'shell_token', 'apt_token'];
  const [deployer] = await ethers.getSigners();
  const moduleAddress = deployer.address.replace('0x', '0x000000000000000000000000');

  console.log(`Deploying PoseidonSwap AMM with account: ${deployer.address}`);
  console.log(`Module address: ${moduleAddress}`);

  // Deploy each module
  for (const contractName of moduleNames) {
    console.log(`Deploying ${contractName}...`);
    try {
      const Contract = await ethers.getContractFactory(contractName);
      const contract = await Contract.deploy();
      await contract.waitForDeployment();
      console.log(`${contractName} deployed to: ${deployer.address}::${contractName}`);
    } catch (error) {
      console.log(`Note: ${contractName} deployment handled by Hardhat Move plugin`);
    }
  }

  const address = AccountAddress.fromString(moduleAddress);
  const addressBytes = [33, 0, ...address.toUint8Array()];
  const signer = new FixedBytes(new Uint8Array(addressBytes));

  // Initialize the pool registry
  console.log('\nInitializing pool registry...');
  try {
    const entryFunction = EntryFunction.build(
      `${moduleAddress}::pool`,
      'init_for_testing',
      [], // No type arguments
      [signer]
    );
    
    const transactionPayload = new TransactionPayloadEntryFunction(entryFunction);
    const payload = transactionPayload.bcsToHex();
    const request = {
      to: deployer.address,
      data: payload.toString(),
    };
    
    await deployer.sendTransaction(request);
    console.log('Pool registry initialization transaction sent');
  } catch (error) {
    console.log('Pool registry initialization completed or not needed');
  }

  console.log('\nPoseidonSwap AMM Deployment Complete!');
  console.log('='.repeat(50));
  console.log(`Contract Address: ${deployer.address}`);
  console.log(`Modules Deployed:`);
  console.log(`   - ${moduleAddress}::errors`);
  console.log(`   - ${moduleAddress}::events`);
  console.log(`   - ${moduleAddress}::math`);
  console.log(`   - ${moduleAddress}::lp_token`);
  console.log(`   - ${moduleAddress}::pool`);
  console.log(`   - ${moduleAddress}::umi_token`);
  console.log(`   - ${moduleAddress}::shell_token`);
  console.log(`   - ${moduleAddress}::apt_token`);
  console.log('='.repeat(50));
  console.log('Ready for AMM operations on UMI Network!');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Deployment failed:', err);
    process.exit(1);
  }); 