// Sui-style transaction utilities for UMI Network
// Based on UMI Network documentation showing Sui transaction structure

// Global type extension for window.ethereum
declare global {
  interface Window {
    ethereum?: any;
  }
}

export const getAccount = async (): Promise<string> => {
  const [account] = await window.ethereum!.request({
    method: 'eth_requestAccounts',
  });
  return account;
};

// Build Sui-style transaction for minting UMI tokens
export const buildMintTransaction = async (amount: string): Promise<any> => {
  const sender = await getAccount();
  
  // Convert amount to proper format (u256 with 18 decimals)
  const amountU256 = BigInt(parseFloat(amount) * Math.pow(10, 18));
  
  // Build Sui-style transaction with MoveCall command
  const transaction = {
    sender: sender,
    commands: [
      {
        MoveCall: {
          package: sender, // Your deployed package address
          module: "umi_token",
          function: "mint_for_testing",
          arguments: [
            sender, // user (signer)
            amountU256.toString() // amount as string
          ],
          type_arguments: []
        }
      }
    ],
    gas_budget: 30400,
    gas_price: 1200000000
  };
  
  return transaction;
};

// Build Sui-style transaction for swapping UMI for Shell
export const buildSwapTransaction = async (umiAmount: string): Promise<any> => {
  const sender = await getAccount();
  
  // Convert to u64 (using pool scaling - 8 decimals for pool operations)
  const amountU64 = Math.floor(parseFloat(umiAmount) * Math.pow(10, 8));
  const minShellOut = 1;
  
  // Build Sui-style transaction with MoveCall command
  const transaction = {
    sender: sender,
    commands: [
      {
        MoveCall: {
          package: sender, // Your deployed package address
          module: "pool",
          function: "swap_umi_for_shell",
          arguments: [
            sender, // user (signer)
            amountU64.toString(), // umi_amount
            minShellOut.toString() // min_shell_out
          ],
          type_arguments: []
        }
      }
    ],
    gas_budget: 1000000,
    gas_price: 1200000000
  };
  
  return transaction;
};

// Send Sui-style transaction via wallet
export const sendSuiTransaction = async (transaction: any): Promise<string> => {
  if (!window.ethereum) {
    throw new Error('No wallet detected');
  }
  
  // Convert JSON to hex-encoded bytes
  const commandsJson = JSON.stringify(transaction.commands);
  const commandsHex = '0x' + Buffer.from(commandsJson, 'utf8').toString('hex');
  
  console.log('Commands JSON:', commandsJson);
  console.log('Commands Hex:', commandsHex);
  
  // Convert Sui transaction to format that wallet can handle
  // Add skipSimulation to bypass the "Simulation Not Supported" popup
  const txHash = await window.ethereum.request({
    method: 'eth_sendTransaction',
    params: [{
      from: transaction.sender,
      to: transaction.sender, // Sui transactions go to sender address
      value: '0x0',
      gas: '0x' + transaction.gas_budget.toString(16),
      gasPrice: '0x' + transaction.gas_price.toString(16),
      data: commandsHex, // Properly hex-encoded command data
      skipSimulation: true, // Bypass simulation popup
    }],
  });
  
  return txHash;
}; 