/// Event emission for PoseidonSwap AMM
/// Provides structured events for off-chain indexing and monitoring
module poseidon_swap::events {
    use aptos_framework::event;

    #[event]
    /// Event emitted when a new pool is created
    struct PoolCreated has drop, store {
        creator: address,
        eth_reserve: u64,
        apt_reserve: u64,
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
        eth_amount: u64,
        apt_amount: u64,
        lp_tokens_minted: u64,
        total_lp_supply: u64,
        eth_reserve: u64,
        apt_reserve: u64,
    }

    #[event]
    /// Event emitted when liquidity is removed from a pool
    struct LiquidityRemoved has drop, store {
        user: address,
        lp_tokens_burned: u64,
        eth_amount: u64,
        apt_amount: u64,
        total_lp_supply: u64,
        eth_reserve: u64,
        apt_reserve: u64,
    }

    #[event]
    /// Event emitted when pool reserves are updated
    struct ReservesUpdated has drop, store {
        pool_address: address,
        eth_reserve: u64,
        apt_reserve: u64,
        k_value: u128,
    }

    #[event]
    /// Event emitted when pool is paused or unpaused
    struct PoolPauseStatusChanged has drop, store {
        admin: address,
        pool_address: address,
        is_paused: bool,
    }

    #[event]
    /// Event emitted when pool fee is updated
    struct PoolFeeUpdated has drop, store {
        admin: address,
        pool_address: address,
        old_fee_bps: u64,
        new_fee_bps: u64,
    }

    /// Emit pool created event
    public fun emit_pool_created(
        creator: address,
        eth_reserve: u64,
        apt_reserve: u64,
        lp_supply: u64,
        pool_address: address,
    ) {
        event::emit(PoolCreated {
            creator,
            eth_reserve,
            apt_reserve,
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
        eth_amount: u64,
        apt_amount: u64,
        lp_tokens_minted: u64,
        total_lp_supply: u64,
        eth_reserve: u64,
        apt_reserve: u64,
    ) {
        event::emit(LiquidityAdded {
            user,
            eth_amount,
            apt_amount,
            lp_tokens_minted,
            total_lp_supply,
            eth_reserve,
            apt_reserve,
        });
    }

    /// Emit liquidity removed event
    public fun emit_liquidity_removed(
        user: address,
        lp_tokens_burned: u64,
        eth_amount: u64,
        apt_amount: u64,
        total_lp_supply: u64,
        eth_reserve: u64,
        apt_reserve: u64,
    ) {
        event::emit(LiquidityRemoved {
            user,
            lp_tokens_burned,
            eth_amount,
            apt_amount,
            total_lp_supply,
            eth_reserve,
            apt_reserve,
        });
    }

    /// Emit reserves updated event
    public fun emit_reserves_updated(
        pool_address: address,
        eth_reserve: u64,
        apt_reserve: u64,
        k_value: u128,
    ) {
        event::emit(ReservesUpdated {
            pool_address,
            eth_reserve,
            apt_reserve,
            k_value,
        });
    }

    /// Emit pool pause status changed event
    public fun emit_pool_pause_status_changed(
        admin: address,
        pool_address: address,
        is_paused: bool,
    ) {
        event::emit(PoolPauseStatusChanged {
            admin,
            pool_address,
            is_paused,
        });
    }

    /// Emit pool fee updated event
    public fun emit_pool_fee_updated(
        admin: address,
        pool_address: address,
        old_fee_bps: u64,
        new_fee_bps: u64,
    ) {
        event::emit(PoolFeeUpdated {
            admin,
            pool_address,
            old_fee_bps,
            new_fee_bps,
        });
    }
} 