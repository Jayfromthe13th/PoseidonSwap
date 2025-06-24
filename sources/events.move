/// Event emission for PoseidonSwap AMM
/// Provides structured events for off-chain indexing and monitoring
module poseidon_swap::events {
    use aptos_framework::event;

    #[event]
    /// Event emitted when a new pool is created
    struct PoolCreated has drop, store {
        creator: address,
        apt_reserve: u64,
        usdc_reserve: u64,
        lp_supply: u64,
        pool_address: address,
    }

    #[event]
    /// Event emitted when a swap is executed
    struct SwapExecuted has drop, store {
        user: address,
        token_in: address,
        amount_in: u64,
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
        new_reserve_in: u64,
        new_reserve_out: u64,
    }

    #[event]
    /// Event emitted when liquidity is added to a pool
    struct LiquidityAdded has drop, store {
        user: address,
        apt_amount: u64,
        usdc_amount: u64,
        lp_tokens_minted: u64,
        total_lp_supply: u64,
        apt_reserve: u64,
        usdc_reserve: u64,
    }

    #[event]
    /// Event emitted when liquidity is removed from a pool
    struct LiquidityRemoved has drop, store {
        user: address,
        lp_tokens_burned: u64,
        apt_amount: u64,
        usdc_amount: u64,
        total_lp_supply: u64,
        apt_reserve: u64,
        usdc_reserve: u64,
    }

    #[event]
    /// Event emitted when pool reserves are updated
    struct ReservesUpdated has drop, store {
        pool_address: address,
        apt_reserve: u64,
        usdc_reserve: u64,
        k_value: u128,
    }

    /// Emit pool created event
    public fun emit_pool_created(
        creator: address,
        apt_reserve: u64,
        usdc_reserve: u64,
        lp_supply: u64,
        pool_address: address,
    ) {
        event::emit(PoolCreated {
            creator,
            apt_reserve,
            usdc_reserve,
            lp_supply,
            pool_address,
        });
    }

    /// Emit swap executed event
    public fun emit_swap_executed(
        user: address,
        token_in: address,
        amount_in: u64,
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
        new_reserve_in: u64,
        new_reserve_out: u64,
    ) {
        event::emit(SwapExecuted {
            user,
            token_in,
            amount_in,
            amount_out,
            reserve_in,
            reserve_out,
            new_reserve_in,
            new_reserve_out,
        });
    }

    /// Emit liquidity added event
    public fun emit_liquidity_added(
        user: address,
        apt_amount: u64,
        usdc_amount: u64,
        lp_tokens_minted: u64,
        total_lp_supply: u64,
        apt_reserve: u64,
        usdc_reserve: u64,
    ) {
        event::emit(LiquidityAdded {
            user,
            apt_amount,
            usdc_amount,
            lp_tokens_minted,
            total_lp_supply,
            apt_reserve,
            usdc_reserve,
        });
    }

    /// Emit liquidity removed event
    public fun emit_liquidity_removed(
        user: address,
        lp_tokens_burned: u64,
        apt_amount: u64,
        usdc_amount: u64,
        total_lp_supply: u64,
        apt_reserve: u64,
        usdc_reserve: u64,
    ) {
        event::emit(LiquidityRemoved {
            user,
            lp_tokens_burned,
            apt_amount,
            usdc_amount,
            total_lp_supply,
            apt_reserve,
            usdc_reserve,
        });
    }

    /// Emit reserves updated event
    public fun emit_reserves_updated(
        pool_address: address,
        apt_reserve: u64,
        usdc_reserve: u64,
        k_value: u128,
    ) {
        event::emit(ReservesUpdated {
            pool_address,
            apt_reserve,
            usdc_reserve,
            k_value,
        });
    }
} 