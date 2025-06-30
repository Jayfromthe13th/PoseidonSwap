/// Main AMM Pool module for PoseidonSwap
/// Handles pool creation, liquidity management, and token swaps for ETH/APT pair
module poseidon_swap::pool {
    use std::signer;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::Object;
    use poseidon_swap::math;
    use poseidon_swap::lp_token;
    use poseidon_swap::events;
    use poseidon_swap::errors;
    use poseidon_swap::eth_token;
    use poseidon_swap::apt_token;

    /// Pool resource holding AMM state for ETH/APT pair
    struct Pool has key {
        eth_reserve: u64,  // ETH reserve scaled down to u64 for calculations
        apt_reserve: u64,  // APT reserve in native u64
        lp_token_metadata: Object<Metadata>,
        fee_bps: u64, // Fee in basis points (e.g., 30 = 0.3%)
        is_paused: bool,
        total_lp_supply: u64, // Track LP token supply
    }

    /// Pool configuration and metadata
    struct PoolInfo has key {
        creator: address,
        created_at: u64,
        total_volume: u128,
        total_fees: u128,
        pool_address: address,
    }

    /// Global pool registry to track the main ETH/APT pool
    struct PoolRegistry has key {
        eth_apt_pool: address,
        initialized: bool,
    }

    // Constants
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3% default fee
    const MIN_LIQUIDITY: u64 = 1000; // Minimum initial liquidity

    /// Initialize the pool registry (called once)
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        move_to(admin, PoolRegistry {
            eth_apt_pool: admin_addr, // Placeholder until real pool is created
            initialized: false,
        });
    }

    /// Initialize a new ETH/APT AMM pool
    public fun create_pool(
        creator: &signer,
        initial_eth_amount: u64,  // ETH amount (scaled to u64)
        initial_apt_amount: u64,  // APT amount
        fee_bps: u64,
    ): address acquires PoolRegistry {
        let creator_addr = signer::address_of(creator);
        
        // Validate inputs
        assert!(initial_eth_amount > 0, errors::insufficient_input_amount());
        assert!(initial_apt_amount > 0, errors::insufficient_input_amount());
        assert!(fee_bps <= 10000, errors::invalid_swap_amount()); // Max 100% fee
        assert!(initial_eth_amount >= MIN_LIQUIDITY, errors::insufficient_input_amount());
        assert!(initial_apt_amount >= MIN_LIQUIDITY, errors::insufficient_input_amount());
        
        // Ensure user has token stores
        eth_token::ensure_token_store(creator);
        apt_token::ensure_token_store(creator);
        
        // Verify user has sufficient balance
        let eth_balance = eth_token::balance_of(creator_addr);
        let apt_balance = apt_token::balance_of(creator_addr);
        assert!(eth_balance >= (initial_eth_amount as u256), errors::insufficient_input_amount());
        assert!(apt_balance >= initial_apt_amount, errors::insufficient_input_amount());
        
        // Create LP token
        let lp_token_metadata = lp_token::initialize_lp_token(
            creator,
            std::string::utf8(b"ETH-APT LP"),
            std::string::utf8(b"ETH_APT_LP"),
            8, // 8 decimals
            std::string::utf8(b""), // icon_uri
            std::string::utf8(b""), // project_uri
        );
        
        // Calculate initial LP tokens (geometric mean)
        let initial_lp_supply = math::sqrt_u64(initial_eth_amount * initial_apt_amount);
        
        // Transfer tokens to pool (simulated - in real implementation would transfer to pool address)
        eth_token::withdraw(creator, (initial_eth_amount as u256));
        apt_token::withdraw(creator, initial_apt_amount);
        
        // Create pool resource
        move_to(creator, Pool {
            eth_reserve: initial_eth_amount,
            apt_reserve: initial_apt_amount,
            lp_token_metadata,
            fee_bps,
            is_paused: false,
            total_lp_supply: initial_lp_supply,
        });
        
        // Create pool info
        move_to(creator, PoolInfo {
            creator: creator_addr,
            created_at: 0, // Would use timestamp in real implementation
            total_volume: 0,
            total_fees: 0,
            pool_address: creator_addr,
        });
        
        // Update registry
        let registry = borrow_global_mut<PoolRegistry>(@poseidon_swap);
        registry.eth_apt_pool = creator_addr;
        registry.initialized = true;
        
        // Mint initial LP tokens to creator
        lp_token::mint_to(creator, lp_token_metadata, initial_lp_supply);
        
        // Emit pool created event
        events::emit_pool_created(
            creator_addr,
            initial_eth_amount,
            initial_apt_amount,
            initial_lp_supply,
            creator_addr,
        );
        
        creator_addr
    }

    /// Add liquidity to the ETH/APT pool
    public fun add_liquidity(
        user: &signer,
        eth_amount: u64,
        apt_amount: u64,
        min_lp_tokens: u64,
    ): u64 acquires Pool, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(eth_amount > 0, errors::insufficient_input_amount());
        assert!(apt_amount > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        eth_token::ensure_token_store(user);
        apt_token::ensure_token_store(user);
        
        // Verify user has sufficient balance
        let eth_balance = eth_token::balance_of(user_addr);
        let apt_balance = apt_token::balance_of(user_addr);
        assert!(eth_balance >= (eth_amount as u256), errors::insufficient_input_amount());
        assert!(apt_balance >= apt_amount, errors::insufficient_input_amount());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate LP tokens to mint
        let lp_tokens = if (pool.total_lp_supply == 0) {
            // First liquidity addition
            math::sqrt_u64(eth_amount * apt_amount)
        } else {
            // Subsequent additions - maintain ratio
            math::calculate_liquidity_amounts(
                eth_amount,
                apt_amount,
                pool.eth_reserve,
                pool.apt_reserve,
                pool.total_lp_supply
            )
        };
        
        // Validate slippage
        assert!(lp_tokens >= min_lp_tokens, errors::slippage_exceeded());
        
        // Transfer tokens from user
        eth_token::withdraw(user, (eth_amount as u256));
        apt_token::withdraw(user, apt_amount);
        
        // Update pool reserves
        pool.eth_reserve = pool.eth_reserve + eth_amount;
        pool.apt_reserve = pool.apt_reserve + apt_amount;
        pool.total_lp_supply = pool.total_lp_supply + lp_tokens;
        
        // Mint LP tokens to user
        lp_token::mint_to(user, pool.lp_token_metadata, lp_tokens);
        
        // Emit liquidity added event
        events::emit_liquidity_added(
            user_addr,
            eth_amount,
            apt_amount,
            lp_tokens,
            pool.total_lp_supply,
            pool.eth_reserve,
            pool.apt_reserve,
        );
        
        lp_tokens
    }

    /// Remove liquidity from the ETH/APT pool
    public fun remove_liquidity(
        user: &signer,
        lp_tokens: u64,
        min_eth: u64,
        min_apt: u64,
    ): (u64, u64) acquires Pool, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(lp_tokens > 0, errors::insufficient_liquidity_burned());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        eth_token::ensure_token_store(user);
        apt_token::ensure_token_store(user);
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Verify user has sufficient LP tokens
        let lp_balance = lp_token::balance_of(user_addr, pool.lp_token_metadata);
        assert!(lp_balance >= lp_tokens, errors::insufficient_liquidity_burned());
        
        // Calculate withdrawal amounts
        let (eth_amount, apt_amount) = math::calculate_withdrawal_amounts(
            lp_tokens,
            pool.eth_reserve,
            pool.apt_reserve,
            pool.total_lp_supply
        );
        
        // Validate slippage
        assert!(eth_amount >= min_eth, errors::slippage_exceeded());
        assert!(apt_amount >= min_apt, errors::slippage_exceeded());
        
        // Burn LP tokens from user
        lp_token::burn_from(user, pool.lp_token_metadata, lp_tokens);
        
        // Update pool reserves
        pool.eth_reserve = pool.eth_reserve - eth_amount;
        pool.apt_reserve = pool.apt_reserve - apt_amount;
        pool.total_lp_supply = pool.total_lp_supply - lp_tokens;
        
        // Transfer tokens to user
        eth_token::deposit(user, (eth_amount as u256));
        apt_token::deposit(user, apt_amount);
        
        // Emit liquidity removed event
        events::emit_liquidity_removed(
            user_addr,
            lp_tokens,
            eth_amount,
            apt_amount,
            pool.total_lp_supply,
            pool.eth_reserve,
            pool.apt_reserve,
        );
        
        (eth_amount, apt_amount)
    }

    /// Swap ETH for APT
    public fun swap_eth_for_apt(
        user: &signer,
        eth_in: u64,
        min_apt_out: u64,
    ): u64 acquires Pool, PoolInfo, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(eth_in > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        eth_token::ensure_token_store(user);
        apt_token::ensure_token_store(user);
        
        // Verify user has sufficient ETH balance
        let eth_balance = eth_token::balance_of(user_addr);
        assert!(eth_balance >= (eth_in as u256), errors::insufficient_input_amount());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate swap output with fee
        let apt_out = math::calculate_swap_output_with_fee(
            pool.eth_reserve,
            pool.apt_reserve,
            eth_in,
            pool.fee_bps
        );
        
        // Validate slippage
        assert!(apt_out >= min_apt_out, errors::slippage_exceeded());
        assert!(apt_out < pool.apt_reserve, errors::insufficient_output_amount());
        
        // Calculate fee for tracking
        let fee_amount = (eth_in * pool.fee_bps) / 10000;
        
        // Transfer tokens
        eth_token::withdraw(user, (eth_in as u256));
        apt_token::deposit(user, apt_out);
        
        // Update pool reserves
        let old_eth_reserve = pool.eth_reserve;
        let old_apt_reserve = pool.apt_reserve;
        pool.eth_reserve = pool.eth_reserve + eth_in;
        pool.apt_reserve = pool.apt_reserve - apt_out;
        
        // Update pool info
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);
        pool_info.total_volume = pool_info.total_volume + (eth_in as u128);
        pool_info.total_fees = pool_info.total_fees + (fee_amount as u128);
        
        // Emit swap executed event
        events::emit_swap_executed(
            user_addr,
            @poseidon_swap, // ETH token address (placeholder)
            eth_in,
            apt_out,
            old_eth_reserve,
            old_apt_reserve,
            pool.eth_reserve,
            pool.apt_reserve,
        );
        
        apt_out
    }

    /// Swap APT for ETH
    public fun swap_apt_for_eth(
        user: &signer,
        apt_in: u64,
        min_eth_out: u64,
    ): u64 acquires Pool, PoolInfo, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(apt_in > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        eth_token::ensure_token_store(user);
        apt_token::ensure_token_store(user);
        
        // Verify user has sufficient APT balance
        let apt_balance = apt_token::balance_of(user_addr);
        assert!(apt_balance >= apt_in, errors::insufficient_input_amount());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate swap output with fee
        let eth_out = math::calculate_swap_output_with_fee(
            pool.apt_reserve,
            pool.eth_reserve,
            apt_in,
            pool.fee_bps
        );
        
        // Validate slippage
        assert!(eth_out >= min_eth_out, errors::slippage_exceeded());
        assert!(eth_out < pool.eth_reserve, errors::insufficient_output_amount());
        
        // Calculate fee for tracking
        let fee_amount = (apt_in * pool.fee_bps) / 10000;
        
        // Transfer tokens
        apt_token::withdraw(user, apt_in);
        eth_token::deposit(user, (eth_out as u256));
        
        // Update pool reserves
        let old_eth_reserve = pool.eth_reserve;
        let old_apt_reserve = pool.apt_reserve;
        pool.apt_reserve = pool.apt_reserve + apt_in;
        pool.eth_reserve = pool.eth_reserve - eth_out;
        
        // Update pool info
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);
        pool_info.total_volume = pool_info.total_volume + (apt_in as u128);
        pool_info.total_fees = pool_info.total_fees + (fee_amount as u128);
        
        // Emit swap executed event
        events::emit_swap_executed(
            user_addr,
            @aptos_framework, // APT token address (placeholder)
            apt_in,
            eth_out,
            old_apt_reserve,
            old_eth_reserve,
            pool.apt_reserve,
            pool.eth_reserve,
        );
        
        eth_out
    }

    // Helper functions
    fun get_pool_address(): address acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@poseidon_swap);
        assert!(registry.initialized, errors::pool_not_found());
        registry.eth_apt_pool
    }

    fun is_paused(pool_addr: address): bool acquires Pool {
        if (!exists<Pool>(pool_addr)) {
            return true
        };
        let pool = borrow_global<Pool>(pool_addr);
        pool.is_paused
    }

    #[view]
    /// Get current pool reserves (ETH, APT)
    public fun get_reserves(pool_address: address): (u64, u64) acquires Pool {
        if (!exists<Pool>(pool_address)) {
            return (0, 0)
        };
        let pool = borrow_global<Pool>(pool_address);
        (pool.eth_reserve, pool.apt_reserve)
    }

    #[view]
    /// Quote swap output amount (view function)
    public fun quote_swap(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64,
    ): u64 {
        math::calculate_swap_output(reserve_in, reserve_out, amount_in)
    }

    #[view]
    /// Quote swap output with fee (view function)
    public fun quote_swap_with_fee(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64,
        fee_bps: u64,
    ): u64 {
        math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, fee_bps)
    }

    #[view]
    /// Get pool info (view function)
    public fun get_pool_info(pool_address: address): (address, u64, u128, u128) acquires PoolInfo {
        if (!exists<PoolInfo>(pool_address)) {
            return (@0x0, 0, 0, 0)
        };
        let info = borrow_global<PoolInfo>(pool_address);
        (info.creator, info.created_at, info.total_volume, info.total_fees)
    }

    #[view]
    /// Check if pool exists (view function)
    public fun pool_exists(pool_address: address): bool {
        exists<Pool>(pool_address) && exists<PoolInfo>(pool_address)
    }

    #[view]
    /// Get the main ETH/APT pool address
    public fun get_main_pool_address(): address acquires PoolRegistry {
        get_pool_address()
    }

    #[view]
    /// Get LP token metadata for a pool (for testing and external access)
    public fun get_lp_token_metadata(pool_address: address): Object<Metadata> acquires Pool {
        let pool = borrow_global<Pool>(pool_address);
        pool.lp_token_metadata
    }

    /// Pause/unpause pool (admin function)
    public fun set_pause_state(admin: &signer, pool_address: address, paused: bool) acquires Pool, PoolInfo {
        // Verify admin is pool creator
        let admin_addr = signer::address_of(admin);
        let pool_info = borrow_global<PoolInfo>(pool_address);
        assert!(admin_addr == pool_info.creator, errors::unauthorized());
        
        // Update pause state
        let pool = borrow_global_mut<Pool>(pool_address);
        pool.is_paused = paused;

        // Emit pause status changed event
        events::emit_pool_pause_status_changed(admin_addr, pool_address, paused);
    }

    /// Update pool fee (admin function)
    public fun set_pool_fee(admin: &signer, pool_address: address, new_fee_bps: u64) acquires Pool, PoolInfo {
        // Verify admin is pool creator
        let admin_addr = signer::address_of(admin);
        let pool_info = borrow_global<PoolInfo>(pool_address);
        assert!(admin_addr == pool_info.creator, errors::unauthorized());
        
        // Validate fee range (0% to 10%)
        assert!(new_fee_bps <= 1000, errors::invalid_fee());
        
        // Update fee
        let pool = borrow_global_mut<Pool>(pool_address);
        let old_fee = pool.fee_bps;
        pool.fee_bps = new_fee_bps;

        // Emit fee updated event
        events::emit_pool_fee_updated(admin_addr, pool_address, old_fee, new_fee_bps);
    }

    /// Emergency stop all operations (admin function)
    public fun emergency_stop(admin: &signer, pool_address: address) acquires Pool, PoolInfo {
        // Verify admin is pool creator
        let admin_addr = signer::address_of(admin);
        let pool_info = borrow_global<PoolInfo>(pool_address);
        assert!(admin_addr == pool_info.creator, errors::unauthorized());
        
        // Force pause the pool
        let pool = borrow_global_mut<Pool>(pool_address);
        pool.is_paused = true;

        // Emit emergency stop event (using pause event)
        events::emit_pool_pause_status_changed(admin_addr, pool_address, true);
    }

    /// Transfer pool ownership (admin function)
    public fun transfer_ownership(admin: &signer, pool_address: address, new_owner: address) acquires PoolInfo {
        // Verify admin is current pool creator
        let admin_addr = signer::address_of(admin);
        let pool_info = borrow_global_mut<PoolInfo>(pool_address);
        assert!(admin_addr == pool_info.creator, errors::unauthorized());
        
        // Validate new owner
        assert!(new_owner != @0x0, errors::invalid_operation());
        assert!(new_owner != admin_addr, errors::invalid_operation());
        
        // Transfer ownership
        pool_info.creator = new_owner;
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }

    #[test_only]
    /// Check if pool is paused (for testing)
    public fun is_paused_for_testing(pool_addr: address): bool acquires Pool {
        is_paused(pool_addr)
    }

    #[view]
    /// Get pool fee (view function)
    public fun get_pool_fee(pool_address: address): u64 acquires Pool {
        if (!exists<Pool>(pool_address)) {
            return 0
        };
        let pool = borrow_global<Pool>(pool_address);
        pool.fee_bps
    }
} 