/// Main AMM Pool module for PoseidonSwap
/// Handles pool creation, liquidity management, and token swaps for UMI/Shell pair
module poseidon_swap::pool {
    use std::signer;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::Object;
    use poseidon_swap::math;
    use poseidon_swap::lp_token;
    use poseidon_swap::events;
    use poseidon_swap::errors;
    use poseidon_swap::umi_token;
    use poseidon_swap::shell_token;

    /// Pool resource holding AMM state for UMI/Shell pair
    struct Pool has key {
        umi_reserve: u64,  // UMI reserve scaled down to u64 for calculations
        shell_reserve: u64,  // Shell reserve in native u64
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

    /// Global pool registry to track the main UMI/Shell pool
    struct PoolRegistry has key {
        umi_shell_pool: address,
        initialized: bool,
    }

    // Constants
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3% default fee
    const MIN_LIQUIDITY: u64 = 1000; // Minimum initial liquidity

    /// Initialize the pool registry (called once)
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        move_to(admin, PoolRegistry {
            umi_shell_pool: admin_addr, // Placeholder until real pool is created
            initialized: false,
        });
    }

    /// Initialize a new UMI/Shell AMM pool
    public fun create_pool(
        creator: &signer,
        initial_umi_amount: u64,  // UMI amount (scaled to u64)
        initial_shell_amount: u64,  // Shell amount
        fee_bps: u64,
    ): address acquires PoolRegistry {
        let creator_addr = signer::address_of(creator);
        
        // Validate inputs
        assert!(initial_umi_amount > 0, errors::insufficient_input_amount());
        assert!(initial_shell_amount > 0, errors::insufficient_input_amount());
        assert!(fee_bps <= 10000, errors::invalid_swap_amount()); // Max 100% fee
        assert!(initial_umi_amount >= MIN_LIQUIDITY, errors::insufficient_input_amount());
        assert!(initial_shell_amount >= MIN_LIQUIDITY, errors::insufficient_input_amount());
        
        // Ensure user has token stores
        umi_token::ensure_token_store(creator);
        shell_token::ensure_token_store(creator);
        
        // Verify user has sufficient balance
        let umi_balance = umi_token::balance_of(creator_addr);
        let shell_balance = shell_token::balance_of(creator_addr);
        assert!(umi_balance >= (initial_umi_amount as u256), errors::insufficient_input_amount());
        assert!(shell_balance >= initial_shell_amount, errors::insufficient_input_amount());
        
        // Create LP token
        let lp_token_metadata = lp_token::initialize_lp_token(
            creator,
            std::string::utf8(b"UMI-Shell LP"),
            std::string::utf8(b"UMISHELL"),
            8, // 8 decimals
            std::string::utf8(b""), // icon_uri
            std::string::utf8(b""), // project_uri
        );
        
        // Calculate initial LP tokens (geometric mean)
        let initial_lp_supply = math::sqrt_u64(initial_umi_amount * initial_shell_amount);
        
        // Transfer tokens to pool (simulated - in real implementation would transfer to pool address)
        umi_token::withdraw(creator, (initial_umi_amount as u256));
        shell_token::withdraw(creator, initial_shell_amount);
        
        // Create pool resource
        move_to(creator, Pool {
            umi_reserve: initial_umi_amount,
            shell_reserve: initial_shell_amount,
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
        registry.umi_shell_pool = creator_addr;
        registry.initialized = true;
        
        // Mint initial LP tokens to creator
        lp_token::mint_to(creator, lp_token_metadata, initial_lp_supply);
        
        // Emit pool created event
        events::emit_pool_created(
            creator_addr,
            initial_umi_amount,
            initial_shell_amount,
            initial_lp_supply,
            creator_addr,
        );
        
        creator_addr
    }

    /// Add liquidity to the UMI/Shell pool
    public fun add_liquidity(
        user: &signer,
        umi_amount: u64,
        shell_amount: u64,
        min_lp_tokens: u64,
    ): u64 acquires Pool, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(umi_amount > 0, errors::insufficient_input_amount());
        assert!(shell_amount > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        umi_token::ensure_token_store(user);
        shell_token::ensure_token_store(user);
        
        // Verify user has sufficient balance
        let umi_balance = umi_token::balance_of(user_addr);
        let shell_balance = shell_token::balance_of(user_addr);
        assert!(umi_balance >= (umi_amount as u256), errors::insufficient_input_amount());
        assert!(shell_balance >= shell_amount, errors::insufficient_input_amount());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate LP tokens to mint
        let lp_tokens = if (pool.total_lp_supply == 0) {
            // First liquidity addition
            math::sqrt_u64(umi_amount * shell_amount)
        } else {
            // Subsequent additions - maintain ratio
            math::calculate_liquidity_amounts(
                umi_amount,
                shell_amount,
                pool.umi_reserve,
                pool.shell_reserve,
                pool.total_lp_supply
            )
        };
        
        // Validate slippage
        assert!(lp_tokens >= min_lp_tokens, errors::slippage_exceeded());
        
        // Transfer tokens from user
        umi_token::withdraw(user, (umi_amount as u256));
        shell_token::withdraw(user, shell_amount);
        
        // Update pool reserves
        pool.umi_reserve = pool.umi_reserve + umi_amount;
        pool.shell_reserve = pool.shell_reserve + shell_amount;
        pool.total_lp_supply = pool.total_lp_supply + lp_tokens;
        
        // Mint LP tokens to user
        lp_token::mint_to(user, pool.lp_token_metadata, lp_tokens);
        
        // Emit liquidity added event
        events::emit_liquidity_added(
            user_addr,
            umi_amount,
            shell_amount,
            lp_tokens,
            pool.total_lp_supply,
            pool.umi_reserve,
            pool.shell_reserve,
        );
        
        lp_tokens
    }

    /// Remove liquidity from the UMI/Shell pool
    public fun remove_liquidity(
        user: &signer,
        lp_tokens: u64,
        min_umi: u64,
        min_shell: u64,
    ): (u64, u64) acquires Pool, PoolRegistry {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(lp_tokens > 0, errors::insufficient_liquidity_burned());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Ensure user has token stores
        umi_token::ensure_token_store(user);
        shell_token::ensure_token_store(user);
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Verify user has sufficient LP tokens
        let lp_balance = lp_token::balance_of(user_addr, pool.lp_token_metadata);
        assert!(lp_balance >= lp_tokens, errors::insufficient_liquidity_burned());
        
        // Calculate withdrawal amounts
        let (umi_amount, shell_amount) = math::calculate_withdrawal_amounts(
            lp_tokens,
            pool.umi_reserve,
            pool.shell_reserve,
            pool.total_lp_supply
        );
        
        // Validate slippage
        assert!(umi_amount >= min_umi, errors::slippage_exceeded());
        assert!(shell_amount >= min_shell, errors::slippage_exceeded());
        
        // Burn LP tokens from user
        lp_token::burn_from(user, pool.lp_token_metadata, lp_tokens);
        
        // Update pool reserves
        pool.umi_reserve = pool.umi_reserve - umi_amount;
        pool.shell_reserve = pool.shell_reserve - shell_amount;
        pool.total_lp_supply = pool.total_lp_supply - lp_tokens;
        
        // Transfer tokens to user
        umi_token::deposit(user, (umi_amount as u256));
        shell_token::deposit(user, shell_amount);
        
        // Emit liquidity removed event
        events::emit_liquidity_removed(
            user_addr,
            lp_tokens,
            umi_amount,
            shell_amount,
            pool.total_lp_supply,
            pool.umi_reserve,
            pool.shell_reserve,
        );
        
        (umi_amount, shell_amount)
    }

    /// Get the current fee rate of the pool (in basis points)
    public fun get_pool_fee(pool_addr: address): u64 acquires Pool {
        let pool = borrow_global<Pool>(pool_addr);
        pool.fee_bps
    }

    #[test_only]
    /// Returns whether the pool is currently paused
    /// This function is only available in test mode
    public fun is_paused_for_testing(pool_addr: address): bool acquires Pool {
        let pool = borrow_global<Pool>(pool_addr);
        pool.is_paused
    }

    /// Emergency stop function to pause pool operations
    public fun emergency_stop(
        admin: &signer,
        pool_addr: address
    ) acquires Pool {
        // Verify caller is pool creator/admin
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool_addr, errors::unauthorized());
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        pool.is_paused = true;
        
        // Emit pause event
        events::emit_pool_paused(pool_addr);
    }

    /// Transfer pool ownership to a new address
    public fun transfer_ownership(
        current_owner: &signer,
        pool_addr: address,
        new_owner: address
    ) acquires PoolInfo {
        // Verify caller is current owner
        let owner_addr = signer::address_of(current_owner);
        assert!(owner_addr == pool_addr, errors::unauthorized());
        assert!(new_owner != @0x0, errors::invalid_address());
        
        // Update pool info
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);
        pool_info.creator = new_owner;
        
        // Emit ownership transfer event
        events::emit_ownership_transferred(pool_addr, owner_addr, new_owner);
    }

    /// Swap UMI for Shell
    public fun swap_umi_for_shell(
        user: &signer,
        umi_in: u64,
        min_shell_out: u64
    ): u64 acquires Pool, PoolRegistry, PoolInfo {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(umi_in > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate output amount with fee
        let shell_out = math::calculate_swap_output_with_fee(
            pool.umi_reserve,
            pool.shell_reserve,
            umi_in,
            pool.fee_bps
        );
        
        // Validate slippage and output
        assert!(shell_out >= min_shell_out, errors::slippage_exceeded());
        assert!(shell_out < pool.shell_reserve, errors::insufficient_liquidity());
        
        // Transfer tokens
        umi_token::withdraw(user, (umi_in as u256));
        shell_token::deposit(user, shell_out);
        
        // Update reserves
        pool.umi_reserve = pool.umi_reserve + umi_in;
        pool.shell_reserve = pool.shell_reserve - shell_out;
        
        // Update volume and fees
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);
        pool_info.total_volume = pool_info.total_volume + (umi_in as u128);
        let fee_amount = (umi_in as u128) * (pool.fee_bps as u128) / 10000;
        pool_info.total_fees = pool_info.total_fees + fee_amount;
        
        // Emit swap event
        events::emit_swap_executed(
            user_addr,
            @umi_token,  // token_in address
            umi_in,
            shell_out,
            pool.umi_reserve,
            pool.shell_reserve,
            pool.umi_reserve + umi_in,
            pool.shell_reserve - shell_out
        );
        
        shell_out
    }

    /// Swap Shell for UMI
    public fun swap_shell_for_umi(
        user: &signer,
        shell_in: u64,
        min_umi_out: u64
    ): u64 acquires Pool, PoolRegistry, PoolInfo {
        let user_addr = signer::address_of(user);
        let pool_addr = get_pool_address();
        
        // Validate inputs
        assert!(shell_in > 0, errors::insufficient_input_amount());
        assert!(!is_paused(pool_addr), errors::pool_paused());
        
        // Get current pool state
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        // Calculate output amount with fee
        let umi_out = math::calculate_swap_output_with_fee(
            pool.shell_reserve,
            pool.umi_reserve,
            shell_in,
            pool.fee_bps
        );
        
        // Validate slippage and output
        assert!(umi_out >= min_umi_out, errors::slippage_exceeded());
        assert!(umi_out < pool.umi_reserve, errors::insufficient_liquidity());
        
        // Transfer tokens
        shell_token::withdraw(user, shell_in);
        umi_token::deposit(user, (umi_out as u256));
        
        // Update reserves
        pool.shell_reserve = pool.shell_reserve + shell_in;
        pool.umi_reserve = pool.umi_reserve - umi_out;
        
        // Update volume and fees
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);
        pool_info.total_volume = pool_info.total_volume + (shell_in as u128);
        let fee_amount = (shell_in as u128) * (pool.fee_bps as u128) / 10000;
        pool_info.total_fees = pool_info.total_fees + fee_amount;
        
        // Emit swap event
        events::emit_swap_executed(
            user_addr,
            @shell_token,  // token_in address
            shell_in,
            umi_out,
            pool.shell_reserve,
            pool.umi_reserve,
            pool.shell_reserve + shell_in,
            pool.umi_reserve - umi_out
        );
        
        umi_out
    }

    // Helper functions
    fun get_pool_address(): address acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@poseidon_swap);
        assert!(registry.initialized, errors::pool_not_found());
        registry.umi_shell_pool
    }

    #[view]
    /// Check if the pool is paused
    public fun is_paused(pool_addr: address): bool acquires Pool {
        if (!exists<Pool>(pool_addr)) {
            return true
        };
        let pool = borrow_global<Pool>(pool_addr);
        pool.is_paused
    }

    #[view]
    /// Get current pool reserves (UMI, Shell)
    public fun get_reserves(pool_address: address): (u64, u64) acquires Pool {
        if (!exists<Pool>(pool_address)) {
            return (0, 0)
        };
        let pool = borrow_global<Pool>(pool_address);
        (pool.umi_reserve, pool.shell_reserve)
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
    /// Get the main UMI/Shell pool address
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
        
        // Validate new fee
        assert!(new_fee_bps <= 10000, errors::invalid_swap_amount()); // Max 100% fee
        
        // Update fee
        let pool = borrow_global_mut<Pool>(pool_address);
        pool.fee_bps = new_fee_bps;

        // Emit fee updated event
        events::emit_pool_fee_updated(admin_addr, pool_address, new_fee_bps);
    }

    /// Resume pool operations after emergency stop
    public fun resume_operations(
        admin: &signer,
        pool_addr: address
    ) acquires Pool {
        // Verify caller is pool creator/admin
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool_addr, errors::unauthorized());
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        pool.is_paused = false;
        
        // Emit resume event
        events::emit_pool_resumed(pool_addr);
    }

    /// Update pool fee rate
    public fun update_fee(
        admin: &signer,
        pool_addr: address,
        new_fee_bps: u64
    ) acquires Pool {
        // Verify caller is pool creator/admin
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == pool_addr, errors::unauthorized());
        
        // Validate new fee
        assert!(new_fee_bps <= 10000, errors::invalid_fee()); // Max 100%
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        pool.fee_bps = new_fee_bps;
        
        // Emit fee update event
        events::emit_pool_fee_updated(admin_addr, pool_addr, new_fee_bps);
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }
} 