// Error codes for PoseidonSwap AMM
module poseidon_swap::errors {
    
    // Pool errors (10-19)
    public fun pool_already_exists(): u64 { 10 }
    public fun pool_not_found(): u64 { 11 }
    public fun pool_not_initialized(): u64 { 12 }
    public fun invalid_fee(): u64 { 13 }
    public fun pool_paused(): u64 { 14 }
    public fun invalid_pool_state(): u64 { 15 }
    public fun invalid_address(): u64 { 16 }
    
    // Liquidity errors (20-29)
    public fun insufficient_liquidity_minted(): u64 { 20 }
    public fun insufficient_input_amount(): u64 { 21 }
    public fun insufficient_output_amount(): u64 { 22 }
    public fun insufficient_liquidity_burned(): u64 { 23 }
    public fun insufficient_liquidity(): u64 { 24 }
    public fun excessive_input_amount(): u64 { 25 }
    
    // Math and calculation errors (30-39)
    public fun overflow(): u64 { 30 }
    public fun division_by_zero(): u64 { 31 }
    public fun underflow(): u64 { 32 }
    public fun invalid_calculation(): u64 { 33 }
    public fun precision_loss(): u64 { 34 }
    public fun amount_too_large(): u64 { 35 }
    
    // Swap errors (40-49)
    public fun invalid_swap_amount(): u64 { 40 }
    public fun slippage_exceeded(): u64 { 41 }
    public fun swap_deadline_exceeded(): u64 { 42 }
    public fun invalid_token_pair(): u64 { 43 }
    public fun identical_addresses(): u64 { 44 }
    
    // Authorization errors (50-59)
    public fun unauthorized(): u64 { 50 }
    public fun insufficient_permission(): u64 { 51 }
    public fun invalid_signer(): u64 { 52 }
    
    // Token errors (60-69)
    public fun invalid_token(): u64 { 60 }
    public fun token_not_registered(): u64 { 61 }
    public fun insufficient_balance(): u64 { 62 }
    public fun transfer_failed(): u64 { 63 }
    public fun account_frozen(): u64 { 64 }
    public fun account_not_found(): u64 { 65 }
    
    // General errors (70-79)
    public fun invalid_argument(): u64 { 70 }
    public fun feature_not_supported(): u64 { 71 }
    public fun operation_not_allowed(): u64 { 72 }
    public fun invalid_state(): u64 { 73 }
    public fun invalid_operation(): u64 { 74 }
} 