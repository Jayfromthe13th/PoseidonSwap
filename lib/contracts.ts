// Contract configuration for PoseidonSwap on UMI Network Devnet
export const CONTRACTS = {
  // Main contract address on UMI Devnet
  POSEIDON_SWAP: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  
  // Module addresses (all under the same base address)
  UMI_TOKEN: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  SHELL_TOKEN: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  POOL: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
} as const;

// Move function selectors for UMI token operations
export const UMI_TOKEN_FUNCTIONS = {
  MINT_FOR_TESTING: 'poseidon_swap::umi_token::mint_for_testing',
  GET_BALANCE: 'poseidon_swap::umi_token::get_balance',
  BALANCE_OF: 'poseidon_swap::umi_token::balance_of',
} as const;

// Move function selectors for pool operations
export const POOL_FUNCTIONS = {
  SWAP_UMI_FOR_SHELL: 'poseidon_swap::pool::swap_umi_for_shell',
  SWAP_SHELL_FOR_UMI: 'poseidon_swap::pool::swap_shell_for_umi',
} as const;

// Basic ABI for Move contract calls via EVM compatibility layer
// Note: This is simplified - actual Move->EVM integration may differ
export const BASIC_ABI = [
  {
    "type": "function",
    "name": "call_move_function",
    "inputs": [
      {"name": "module_address", "type": "address"},
      {"name": "module_name", "type": "string"},
      {"name": "function_name", "type": "string"},
      {"name": "args", "type": "bytes[]"}
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const; 