import { AccountAddress, EntryFunction, FixedBytes, TransactionPayloadEntryFunction, U256 } from '@aptos-labs/ts-sdk';
import { bcs } from '@mysten/bcs';
import { createPublicClient, createWalletClient, custom, defineChain } from 'viem';
import { publicActionsL2, walletActionsL2 } from 'viem/op-stack';

// Define Umi Devnet chain
export const devnet = defineChain({
  id: 42069,
  sourceId: 42069,
  name: 'Umi',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['https://devnet.uminetwork.com'],
    },
  },
});

// Get connected wallet account
export const getAccount = async (): Promise<string> => {
  if (typeof window === 'undefined' || !window.ethereum) {
    throw new Error('No wallet detected');
  }
  
  const [account] = await window.ethereum.request({
    method: 'eth_requestAccounts',
  });
  return account;
};

// Get account address (use standard Ethereum format for Umi Devnet)
export const getMoveAccount = async (): Promise<string> => {
  const account = await getAccount();
  // For Umi Devnet, use the standard Ethereum address format
  return account;
};

// Create public client for reading blockchain state
export const publicClient = () =>
  createPublicClient({
    chain: devnet,
    transport: custom(window.ethereum!),
  }).extend(publicActionsL2());

// Create wallet client for sending transactions
export const walletClient = () =>
  createWalletClient({
    chain: devnet,
    transport: custom(window.ethereum!),
  }).extend(walletActionsL2());

// Convert address into serialized signer object for Move
export const getSigner = (address: string): FixedBytes => {
  // For Umi Devnet, we need to convert the Ethereum address to proper Move format
  // Pad the address to 32 bytes for Move compatibility
  const paddedAddress = address.slice(0, 2) + '000000000000000000000000' + address.slice(2);
  
  // Signer value is defined as Signer(AccountAddress) in Rust, so when it's deserialized it needs
  // an extra 0 in the beginning to indicate that the address is the first field.
  // Then the entire data is serialized as a vector of size 33 bytes.
  const addressBytes = [33, 0, ...AccountAddress.fromString(paddedAddress).toUint8Array()];
  return new FixedBytes(new Uint8Array(addressBytes));
};

// Create Move transaction payload for UMI token operations
export const createUMITokenPayload = async (method: string, amount?: string): Promise<`0x${string}`> => {
  const moveAccount = await getMoveAccount();
  const signer = getSigner(moveAccount);
  
  // For Move contract addresses, we need the padded format
  const paddedAddress = moveAccount.slice(0, 2) + '000000000000000000000000' + moveAccount.slice(2);
  const userAddress = AccountAddress.fromString(paddedAddress);
  
  // Build arguments based on the method
  let args: any[] = [];
  
  if (method === 'mint') {
    // mint(admin: &signer, to: address, amount: u256)
    args = [signer, userAddress, new U256(BigInt(amount || '0'))];
  } else if (method === 'mint_for_testing' && amount) {
    // mint_for_testing(user: &signer, amount: u256) - but this is not an entry function
    args = [signer, new U256(BigInt(amount))];
  }
  
  const entryFunction = EntryFunction.build(
    `${paddedAddress}::umi_token`,
    method,
    [], // No type arguments
    args
  );
  
  const transactionPayload = new TransactionPayloadEntryFunction(entryFunction);
  return transactionPayload.bcsToHex().toString() as `0x${string}`;
};

// Create Move transaction payload for pool operations
export const createPoolPayload = async (method: string, amount?: string): Promise<`0x${string}`> => {
  const moveAccount = await getMoveAccount();
  const signer = getSigner(moveAccount);
  
  // Build arguments based on the method
  let args: any[] = [signer];
  
  if ((method === 'swap_umi_for_shell' || method === 'swap_shell_for_umi') && amount) {
    // Convert amount string to U256 for Move
    const u256Amount = new U256(BigInt(amount));
    args.push(u256Amount);
  }
  
  // For Move contract addresses, we need the padded format
  const paddedAddress = moveAccount.slice(0, 2) + '000000000000000000000000' + moveAccount.slice(2);
  
  const entryFunction = EntryFunction.build(
    `${paddedAddress}::pool`,
    method,
    [], // No type arguments
    args
  );
  
  const transactionPayload = new TransactionPayloadEntryFunction(entryFunction);
  return transactionPayload.bcsToHex().toString() as `0x${string}`;
};

// Extract output data from Move transaction response
export const extractOutput = (data: `0x${string}` | undefined): Uint8Array => {
  if (!data) throw Error('No data found');
  if (typeof data !== 'string') throw Error('Data is not a hex string');
  
  // Convert hex string to Uint8Array
  const bytes = new Uint8Array(Buffer.from(data.slice(2), 'hex'));
  
  // The returned data is a vector of results with mostly a single result.
  // Each result is a tuple of output data bytes followed by the serialized Move type layout.
  // The following code extracts the output bytes from inside this complex returned data structure.
  return new Uint8Array(bcs.vector(bcs.tuple([bcs.vector(bcs.u8())])).parse(bytes)[0][0]);
};