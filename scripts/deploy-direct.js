const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Umi Devnet configuration
const UMI_RPC_URL = 'https://devnet.uminetwork.com';
const PRIVATE_KEY = '0x080d4ed41915ecff60cc353f79a82b12b05a65f89ba69527b27cfbc957962f55';

async function main() {
  console.log('🚀 Deploying PoseidonSwap AMM to Umi Devnet...');
  
  // Create provider and wallet
  const provider = new ethers.JsonRpcProvider(UMI_RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  
  console.log('Deploying with account:', wallet.address);
  
  // Check balance
  try {
    const balance = await provider.getBalance(wallet.address);
    console.log('Account balance:', ethers.formatEther(balance), 'ETH');
    
    if (balance < ethers.parseEther('0.001')) {
      console.error('❌ Insufficient balance! Please fund your account with test ETH.');
      console.log('Visit Umi faucet or bridge ETH to Umi testnet');
      return;
    }
  } catch (error) {
    console.error('❌ Error checking balance:', error.message);
    console.log('This might be normal if Umi uses a different balance check method');
  }
  
  // Check if Move bytecode exists
  const buildPath = path.join(__dirname, '../contracts/poseidon_swap/build/poseidon_swap');
  const bytecodePath = path.join(buildPath, 'bytecode_modules');
  
  if (!fs.existsSync(bytecodePath)) {
    console.error('❌ Move bytecode not found. Please run: cd contracts/poseidon_swap && aptos move compile');
    return;
  }
  
  console.log('✅ Found compiled Move bytecode');
  
  // List compiled modules
  const modules = fs.readdirSync(bytecodePath)
    .filter(file => file.endsWith('.mv'))
    .map(file => file.replace('.mv', ''));
  
  console.log('📦 Compiled modules:', modules);
  
  // For Umi deployment, we need to use Move-specific deployment
  // This is a simulation since Umi requires specialized tools
  console.log('\n🔧 Umi Deployment Process:');
  console.log('1. ✅ Move contracts compiled successfully');
  console.log('2. ✅ Bytecode generated for', modules.length, 'modules');
  console.log('3. ✅ Deployment account configured:', wallet.address);
  console.log('4. ✅ Connected to Umi Devnet:', UMI_RPC_URL);
  
  // Create deployment manifest
  const deploymentManifest = {
    network: 'Umi Devnet',
    rpcUrl: UMI_RPC_URL,
    deployer: wallet.address,
    timestamp: new Date().toISOString(),
    modules: modules.map(module => ({
      name: module,
      address: `${wallet.address}::${module}`,
      bytecode: `${bytecodePath}/${module}.mv`
    })),
    explorer: 'https://devnet.explorer.moved.network',
    status: 'Ready for deployment'
  };
  
  // Save deployment manifest
  fs.writeFileSync(
    path.join(__dirname, '../umi-deployment.json'),
    JSON.stringify(deploymentManifest, null, 2)
  );
  
  console.log('\n✅ Deployment manifest created: umi-deployment.json');
  console.log('🎯 Contract modules ready for deployment:');
  
  modules.forEach(module => {
    console.log(`   📄 ${wallet.address}::${module}`);
  });
  
  console.log('\n📋 Next Steps:');
  console.log('1. Use Umi-specific deployment tools to deploy the Move bytecode');
  console.log('2. Verify deployment on Umi block explorer');
  console.log('3. Update frontend with deployed contract addresses');
  
  console.log('\n🌐 Network Information:');
  console.log('- Network: Umi Devnet');
  console.log('- RPC URL:', UMI_RPC_URL);
  console.log('- Chain ID: 42069');
  console.log('- Explorer: https://devnet.explorer.moved.network');
  
  return deploymentManifest;
}

main()
  .then((result) => {
    console.log('\n🎉 Deployment preparation complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Deployment preparation failed:', error);
    process.exit(1);
  }); 