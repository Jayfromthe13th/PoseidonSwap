const { ethers } = require('hardhat');
const { AccountAddress, EntryFunction, FixedBytes, parseTypeTag } = require('@aptos-labs/ts-sdk');
const { TransactionPayloadEntryFunction, TypeTagSigner } = require('@aptos-labs/ts-sdk');

async function main() {
  const contractName = 'poseidon_swap';
  const [deployer] = await ethers.getSigners();
  
  console.log('Deploying PoseidonSwap AMM with account:', deployer.address);
  console.log('Account balance:', (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy the main contract
  const PoseidonSwap = await ethers.getContractFactory(contractName);
  const poseidonSwap = await PoseidonSwap.deploy();
  await poseidonSwap.waitForDeployment();
  
  console.log(`PoseidonSwap AMM deployed to: ${deployer.address}::${contractName}`);
  console.log('Contract modules deployed:');
  console.log(`- ${deployer.address}::umi_token`);
  console.log(`- ${deployer.address}::shell_token`);
  console.log(`- ${deployer.address}::apt_token`);
  console.log(`- ${deployer.address}::pool`);
  console.log(`- ${deployer.address}::lp_token`);
  console.log(`- ${deployer.address}::math`);
  console.log(`- ${deployer.address}::events`);
  console.log(`- ${deployer.address}::errors`);

  // Initialize the tokens
  console.log('\nInitializing tokens...');
  
  const moduleAddress = deployer.address.replace('0x', '0x000000000000000000000000');
  const address = AccountAddress.fromString(moduleAddress);
  const addressBytes = [33, 0, ...address.toUint8Array()];
  const signer = new FixedBytes(new Uint8Array(addressBytes));

  // Initialize UMI token
  try {
    const umiInitFunction = EntryFunction.build(
      `${moduleAddress}::umi_token`,
      'initialize',
      [],
      [signer]
    );
    const umiTransactionPayload = new TransactionPayloadEntryFunction(umiInitFunction);
    const umiPayload = umiTransactionPayload.bcsToHex();
    
    const umiRequest = {
      to: deployer.address,
      data: umiPayload.toString(),
    };
    
    const umiTx = await deployer.sendTransaction(umiRequest);
    console.log('UMI token initialized:', umiTx.hash);
  } catch (error) {
    console.log('UMI token initialization error (may already be initialized):', error.message);
  }

  // Initialize SHELL token
  try {
    const shellInitFunction = EntryFunction.build(
      `${moduleAddress}::shell_token`,
      'initialize',
      [],
      [signer]
    );
    const shellTransactionPayload = new TransactionPayloadEntryFunction(shellInitFunction);
    const shellPayload = shellTransactionPayload.bcsToHex();
    
    const shellRequest = {
      to: deployer.address,
      data: shellPayload.toString(),
    };
    
    const shellTx = await deployer.sendTransaction(shellRequest);
    console.log('SHELL token initialized:', shellTx.hash);
  } catch (error) {
    console.log('SHELL token initialization error (may already be initialized):', error.message);
  }

  // Initialize APT token
  try {
    const aptInitFunction = EntryFunction.build(
      `${moduleAddress}::apt_token`,
      'initialize',
      [],
      [signer]
    );
    const aptTransactionPayload = new TransactionPayloadEntryFunction(aptInitFunction);
    const aptPayload = aptTransactionPayload.bcsToHex();
    
    const aptRequest = {
      to: deployer.address,
      data: aptPayload.toString(),
    };
    
    const aptTx = await deployer.sendTransaction(aptRequest);
    console.log('APT token initialized:', aptTx.hash);
  } catch (error) {
    console.log('APT token initialization error (may already be initialized):', error.message);
  }

  // Initialize the pool
  try {
    const poolInitFunction = EntryFunction.build(
      `${moduleAddress}::pool`,
      'initialize',
      [],
      [signer]
    );
    const poolTransactionPayload = new TransactionPayloadEntryFunction(poolInitFunction);
    const poolPayload = poolTransactionPayload.bcsToHex();
    
    const poolRequest = {
      to: deployer.address,
      data: poolPayload.toString(),
    };
    
    const poolTx = await deployer.sendTransaction(poolRequest);
    console.log('Pool initialized:', poolTx.hash);
  } catch (error) {
    console.log('Pool initialization error (may already be initialized):', error.message);
  }

  console.log('\n=== DEPLOYMENT COMPLETE ===');
  console.log('Contract Address:', deployer.address);
  console.log('Network: Umi Devnet');
  console.log('Block Explorer: https://explorer.uminetwork.com/');
  console.log(`Search for address: ${deployer.address}`);
  console.log('\nNext steps:');
  console.log('1. Verify contracts on Umi block explorer');
  console.log('2. Update frontend configuration with contract addresses');
  console.log('3. Test basic functionality (minting, swapping)');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Deployment failed:', err);
    process.exit(1);
  }); 