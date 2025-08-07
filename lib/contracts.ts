// Contract configuration for PoseidonSwap on UMI Network Devnet
export const CONTRACTS = {
  // Main contract address on UMI Devnet
  POSEIDON_SWAP: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  
  // Module addresses (all under the same base address)
  SHELL_TOKEN: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  PEARL_TOKEN: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
  POOL: '0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A',
} as const;

// Move function selectors for Shell token operations
export const SHELL_TOKEN_FUNCTIONS = {
  MINT: 'poseidon_swap::shell_token::mint',
  VIEW_BALANCE: 'poseidon_swap::shell_token::view_balance',
  BALANCE_OF: 'poseidon_swap::shell_token::balance_of',
} as const;

// Move function selectors for pool operations
export const POOL_FUNCTIONS = {
  SWAP_SHELL_FOR_PEARL: 'poseidon_swap::pool::swap_shell_for_pearl',
  SWAP_PEARL_FOR_SHELL: 'poseidon_swap::pool::swap_pearl_for_shell',
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