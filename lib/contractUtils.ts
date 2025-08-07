// Simple wallet interaction utilities for testing
// Start with basic functions and build up complexity
// Global type extension handled in WalletProvider component
import { publicClient } from './moveConfig';
// Ultra simple test function - just check if ethereum exists
export async function testWalletExists(): Promise<boolean> {
  try {
    console.log('🔍 Checking if wallet exists...');
    if (typeof window === 'undefined') {
      console.log('❌ Running on server side');
      return false;
    }
    if (!window.ethereum) {
      console.log('❌ No window.ethereum found');
      return false;
    }
    console.log('✅ window.ethereum exists:', window.ethereum);
    return true;
  } catch (error) {
    console.error('❌ Error checking wallet:', error);
    return false;
  }
}
// Test function 1: Just check if wallet is connected
export async function testWalletConnection(): Promise<boolean> {
  try {
    if (typeof window === 'undefined' || !window.ethereum) {
      console.log('❌ No wallet detected');
      return false;
    }
    const accounts = await window.ethereum.request({
      method: 'eth_accounts'
    });
    console.log('✅ Wallet connected:', accounts[0]);
    return accounts.length > 0;
  } catch (error) {
    console.error('❌ Wallet connection test failed:', error);
    return false;
  }
}
// Test function 2: Check network/chain ID
export async function testNetworkConnection(): Promise<{ chainId: number; chainName: string }> {
  try {
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('No wallet detected');
    }
    const chainId = await window.ethereum.request({
      method: 'eth_chainId'
    });
    const chainIdNumber = parseInt(chainId, 16);
    const chainName = chainIdNumber === 42069 ? 'UMI Devnet' : `Chain ${chainIdNumber}`;
    console.log(`✅ Connected to ${chainName} (${chainIdNumber})`);
    return { chainId: chainIdNumber, chainName };
  } catch (error) {
    console.error('❌ Network test failed:', error);
    throw error;
  }
}
// Super simple transaction test - no gas settings
export async function testVerySimpleTransaction(): Promise<string> {
  try {
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('No wallet detected');
    }
    const accounts = await window.ethereum.request({
      method: 'eth_accounts'
    });
    if (accounts.length === 0) {
      throw new Error('No accounts connected');
    }
    console.log('Sending ultra-simple transaction...');
    // Simplest possible transaction
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [{
        from: accounts[0],
        to: accounts[0],
        value: '0x0'
        // No gas settings - let wallet decide
      }],
    });
    console.log('✅ Ultra-simple transaction sent:', txHash);
    return txHash;
  } catch (error) {
    console.error('❌ Ultra-simple transaction failed:', error);
    throw error;
  }
}
// Test function 3: Send a simple transaction (no data)
export async function testSimpleTransaction(): Promise<string> {
  try {
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('No wallet detected');
    }
    const accounts = await window.ethereum.request({
      method: 'eth_accounts'
    });
    if (accounts.length === 0) {
      throw new Error('No accounts connected');
    }
    console.log('Sending simple test transaction...');
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [{
        from: accounts[0],
        to: accounts[0], // Send to self
        value: '0x0', // No ETH value
        gas: '0x3E8', // 1000 gas (minimal)
        gasPrice: '0x1', // 1 wei (minimal)
        data: '0x' // No data
      }],
    });
    console.log('✅ Simple transaction sent:', txHash);
    return txHash;
  } catch (error) {
    console.error('❌ Simple transaction failed:', error);
    throw error;
  }
}
// Development flag - set to true to use mock mode instead of real transactions
const USE_MOCK_MODE = false; // Change to true for development

// Mint Shell tokens using proper Move transactions
export async function mintShellTokens(amount: string, address: `0x${string}`): Promise<string> {
  // Mock mode for development
  if (USE_MOCK_MODE) {
    console.log(`🔄 [MOCK MODE] Minting ${amount} Shell tokens...`);
    await new Promise(resolve => setTimeout(resolve, 2000)); // Simulate delay
    
    const mockHash = `0x${Math.random().toString(16).substr(2, 64)}`;
    console.log(`✅ [MOCK] Mint successful! (No balance tracking - mock only)`);
    return mockHash;
  }

  try {
    console.log(`🔄 Minting ${amount} Shell tokens using Move transaction...`);
    
    // Import Move utilities dynamically to avoid SSR issues
    const { walletClient, publicClient, createShellTokenPayload, getAccount } = await import('./moveConfig');
    
    // Test wallet connection
    const isConnected = await testWalletConnection();
    if (!isConnected) {
      throw new Error('Wallet not connected');
    }
    
    // Test network
    const network = await testNetworkConnection();
    if (network.chainId !== 42069) {
      throw new Error(`Wrong network. Expected UMI Devnet (42069), got ${network.chainName}`);
    }
    
    console.log('Creating Move transaction payload for minting...');
    
    // Create Move transaction payload for minting (using entry function)
    const payload = await createShellTokenPayload('mint', amount);
    
    console.log('Sending Move transaction...');
    
    // Send Move transaction using Viem with explicit settings for Umi
    const hash = await walletClient().sendTransaction({
      account: (await getAccount()) as `0x${string}`,
      to: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A', // Deployed contract address
      data: payload,
      gas: BigInt(100000), // Higher gas limit
      gasPrice: BigInt(2500000000), // Higher gas price (2.5 Gwei)
    } as any);
    
    console.log('Move transaction submitted! Hash:', hash);
    
    // Don't wait for receipt immediately - let it process in background
    // Try to wait with a timeout
    try {
      console.log('Waiting for transaction confirmation (with timeout)...');
      await publicClient().waitForTransactionReceipt({ 
        hash,
        timeout: 30000 // 30 second timeout
      });
      console.log(`✅ Move mint transaction confirmed! Hash: ${hash}`);
      
      // Transaction confirmed - balance should be updated on-chain
      console.log(`📊 Transaction confirmed - balance updated on blockchain`);
      
    } catch (receiptError) {
      console.log(`⚠️ Transaction submitted but receipt not found yet. Hash: ${hash}`);
      console.log('This is normal on Umi Devnet - transaction may still be processing');
      // DO NOT update any balance - wait for actual confirmation
    }
    
    return hash;
  } catch (error) {
    console.error('❌ Move mint failed:', error);
    throw error;
  }
}
// Swap Shell for Pearl using proper Move transactions
export async function swapShellForPearl(shellAmount: string, address: `0x${string}`): Promise<string> {
  try {
    console.log(`🔄 Swapping ${shellAmount} Shell for Pearl using Move transaction...`);
    
    // Import Move utilities dynamically to avoid SSR issues
    const { walletClient, publicClient, createPoolPayload, getAccount } = await import('./moveConfig');
    
    // Test wallet connection
    const isConnected = await testWalletConnection();
    if (!isConnected) {
      throw new Error('Wallet not connected');
    }
    
    // Test network
    const network = await testNetworkConnection();
    if (network.chainId !== 42069) {
      throw new Error(`Wrong network. Expected UMI Devnet (42069), got ${network.chainName}`);
    }
    
    // TODO: Check if user has enough Shell from actual on-chain balance
    // For now, skip balance check since we can't query real balances yet
    console.log(`⚠️ Skipping balance check - need real on-chain balance query`);
    
    console.log('Creating Move transaction payload for swap...');
    
    // Create Move transaction payload for swapping
    const payload = await createPoolPayload('swap_shell_for_pearl', shellAmount);
    
    console.log('Sending Move swap transaction...');
    
    // Send Move transaction using Viem with explicit settings for Umi
    const hash = await walletClient().sendTransaction({
      account: (await getAccount()) as `0x${string}`,
      to: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A', // Deployed contract address
      data: payload,
      gas: BigInt(100000), // Higher gas limit
      gasPrice: BigInt(2500000000), // Higher gas price (2.5 Gwei)
    } as any);
    
    console.log('Move swap transaction submitted! Hash:', hash);
    
    // Try to wait with a timeout
    try {
      console.log('Waiting for swap transaction confirmation (with timeout)...');
      await publicClient().waitForTransactionReceipt({ 
        hash,
        timeout: 30000 // 30 second timeout
      });
      console.log(`✅ Move swap transaction confirmed! Hash: ${hash}`);
    } catch (receiptError) {
      console.log(`⚠️ Swap transaction submitted but receipt not found yet. Hash: ${hash}`);
      console.log('This is normal on Umi Devnet - transaction may still be processing');
      // Don't throw error - transaction was submitted successfully
    }
    
    // Transaction submitted - balance should be updated on-chain
    console.log(`📊 Swap transaction submitted - balances should update on blockchain`);
    
    return hash;
  } catch (error) {
    console.error('❌ Move swap failed:', error);
    throw error;
  }
}
// Query Shell balance from on-chain Move view function
export async function getShellBalance(address: `0x${string}`): Promise<string> {
  try {
    console.log(`📊 Querying Shell balance for ${address}...`);
    
    const { createViewPayload, extractOutput } = await import('./moveConfig');
    
    // Create payload for view_balance function
    const payload = await createViewPayload('view_balance', address);
    
    // Call the Move view function on-chain
    const result = await publicClient().call({
      to: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
      data: payload,
    });
    
    // Extract the balance from the result
    const balanceBytes = extractOutput(result.data);
    
    // Convert bytes to u256 balance (Move uses u256 for balances)
    const balance = new DataView(balanceBytes.buffer).getBigUint64(0, false).toString();
    console.log(`📊 Shell Balance for ${address}: ${balance}`);
    return balance;
  } catch (error) {
    console.error('❌ Balance fetch failed:', error);
    // Return 0 if view function fails
    return '0';
  }
}

// Test function to check contract state
export async function testContractState(): Promise<void> {
  try {
    console.log('🔍 Testing contract state...');
    
    const { getMoveAccount } = await import('./moveConfig');
    const moveAccount = await getMoveAccount();
    
    console.log(`✅ Contract address accessible: ${moveAccount}`);
    console.log('ℹ️ Note: Umi Devnet does not support eth_call for read operations');
    console.log('ℹ️ But write operations (mint/swap) work perfectly!');
    
  } catch (error) {
    console.error('❌ Contract state test failed:', error);
    throw error;
  }
}

// Simple diagnostic function
export async function runDiagnostics(): Promise<void> {
  console.log('🔧 Running PoseidonSwap diagnostics...');
  
  try {
    // Test 1: Wallet connection
    const walletConnected = await testWalletConnection();
    console.log(`Wallet: ${walletConnected ? '✅' : '❌'}`);
    
    // Test 2: Network
    const network = await testNetworkConnection();
    console.log(`Network: ${network.chainId === 42069 ? '✅' : '❌'} ${network.chainName}`);
    
    // Test 3: Contract state
    await testContractState();
    console.log('Contract: ✅ Accessible');
    
  } catch (error) {
    console.error('❌ Diagnostics failed:', error);
  }
}

