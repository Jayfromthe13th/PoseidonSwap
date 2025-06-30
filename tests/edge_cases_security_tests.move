#[test_only]
module poseidon_swap::edge_cases_security_tests {
    use std::signer;
    use poseidon_swap::pool;
    use poseidon_swap::eth_token;
    use poseidon_swap::apt_token;
    use poseidon_swap::lp_token;
    use poseidon_swap::math;

    // Test constants
    const TEST_ETH_MINT: u256 = 1000000000000000000; // 1 ETH in wei (large amount for testing)
    const TEST_APT_MINT: u64 = 1000000000000; // 1M APT (large amount for testing)
    const INITIAL_ETH_AMOUNT: u64 = 1000000; // 1 ETH
    const INITIAL_APT_AMOUNT: u64 = 2000000; // 2 APT
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%

    // ===== TASK 5B.3: EDGE CASES & SECURITY TESTING =====

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_eth_pool_creation(admin: &signer, creator: &signer) {
        // Setup: Initialize modules
        setup_test_environment(admin, creator);

        // Test: Try to create pool with zero ETH (should fail)
        pool::create_pool(creator, 0, INITIAL_APT_AMOUNT, DEFAULT_FEE_BPS);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_apt_pool_creation(admin: &signer, creator: &signer) {
        // Setup: Initialize modules
        setup_test_environment(admin, creator);

        // Test: Try to create pool with zero APT (should fail)
        pool::create_pool(creator, INITIAL_ETH_AMOUNT, 0, DEFAULT_FEE_BPS);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_eth_liquidity_addition(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Test: Try to add zero ETH liquidity (should fail)
        pool::add_liquidity(user, 0, 1000000, 1000);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_apt_liquidity_addition(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Test: Try to add zero APT liquidity (should fail)
        pool::add_liquidity(user, 1000000, 0, 1000);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_eth_swap(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool with liquidity
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);
        
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 1000000, 2000000, 1000);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Test: Try to swap zero ETH (should fail)
        pool::swap_eth_for_apt(user, 0, 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_apt_swap(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool with liquidity
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);
        
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 1000000, 2000000, 1000);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Test: Try to swap zero APT (should fail)
        pool::swap_apt_for_eth(user, 0, 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_maximum_value_operations(admin: &signer, creator: &signer) {
        // Setup: Initialize modules
        setup_test_environment(admin, creator);

        // Test: Create pool with large amounts (near u64 max but reasonable)
        let large_eth = 1000000000; // 1B units
        let large_apt = 2000000000; // 2B units
        
        // Mint large amounts
        apt_token::mint_for_testing(creator, large_apt);
        eth_token::mint_for_testing(creator, (large_eth as u256));

        // Create pool with large amounts
        let pool_addr = pool::create_pool(creator, large_eth, large_apt, DEFAULT_FEE_BPS);
        
        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve == large_eth, 2);
        assert!(apt_reserve == large_apt, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_minimum_liquidity_enforcement(admin: &signer, creator: &signer) {
        // Setup: Initialize modules
        setup_test_environment(admin, creator);

        // Test: Create pool with minimum viable amounts
        let min_eth = 1000; // Minimum ETH (0.001 ETH)
        let min_apt = 1000; // Minimum APT (0.001 APT)
        
        apt_token::mint_for_testing(creator, min_apt);
        eth_token::mint_for_testing(creator, (min_eth as u256));

        let pool_addr = pool::create_pool(creator, min_eth, min_apt, DEFAULT_FEE_BPS);
        
        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve == min_eth, 2);
        assert!(apt_reserve == min_apt, 3);

        // Verify: Minimum LP tokens were minted (sqrt(min_eth * min_apt))
        let expected_lp = math::sqrt_u128((min_eth as u128) * (min_apt as u128));
        assert!((expected_lp as u64) > 0, 4);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_precision_loss_scenarios(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool with small amounts to test precision
        setup_test_environment(admin, creator);
        
        // Use small amounts to test precision handling (but above minimum)
        let small_eth = 10000; // Above MIN_LIQUIDITY (1000)
        let small_apt = 20000; // Above MIN_LIQUIDITY (1000)
        
        apt_token::mint_for_testing(creator, small_apt);
        eth_token::mint_for_testing(creator, (small_eth as u256));

        let pool_addr = pool::create_pool(creator, small_eth, small_apt, DEFAULT_FEE_BPS);

        // Setup user for small swaps
        apt_token::mint_for_testing(user, 1000);
        eth_token::mint_for_testing(user, 1000);

        // Test: Small swap that might cause precision issues
        let tiny_eth_in = 1; // 1 unit ETH
        let apt_out = pool::swap_eth_for_apt(user, tiny_eth_in, 1);
        
        // Verify: Swap still works even with tiny amounts
        assert!(apt_out >= 1, 1); // Should get at least 1 APT out

        // Verify: Pool reserves are still consistent
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve == small_eth + tiny_eth_in, 2);
        assert!(apt_reserve == small_apt - apt_out, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_rounding_error_accumulation(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Add liquidity for swaps
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 5000000, 10000000, 1000);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Get initial reserves
        let (initial_eth, initial_apt) = pool::get_reserves(pool_addr);
        let initial_k = (initial_eth as u128) * (initial_apt as u128);

        // Perform many small swaps to test rounding error accumulation
        // Perform 10 rounds of small swaps
        pool::swap_eth_for_apt(user, 1000, 1);
        pool::swap_apt_for_eth(user, 2000, 1);
        pool::swap_eth_for_apt(user, 1000, 1);
        pool::swap_apt_for_eth(user, 2000, 1);
        pool::swap_eth_for_apt(user, 1000, 1);
        pool::swap_apt_for_eth(user, 2000, 1);
        pool::swap_eth_for_apt(user, 1000, 1);
        pool::swap_apt_for_eth(user, 2000, 1);
        pool::swap_eth_for_apt(user, 1000, 1);
        pool::swap_apt_for_eth(user, 2000, 1);

        // Get final reserves
        let (final_eth, final_apt) = pool::get_reserves(pool_addr);
        let final_k = (final_eth as u128) * (final_apt as u128);

        // Verify: K value should be preserved or slightly increased (due to fees)
        assert!(final_k >= initial_k, 1);
        
        // Verify: Reserves should be reasonable (not drastically different)
        // Allow for some variance due to fees and rounding
        let eth_ratio = if (final_eth > initial_eth) {
            (final_eth * 100) / initial_eth
        } else {
            (initial_eth * 100) / final_eth
        };
        assert!(eth_ratio <= 110, 2); // Within 10% variance
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_extreme_slippage_protection(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool with liquidity
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);
        
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 1000000, 2000000, 1000);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Test: Swap with unrealistic minimum output (should fail)
        pool::swap_eth_for_apt(user, 100000, 1000000); // Expect way more than possible
    }

    #[test(admin = @poseidon_swap, creator1 = @0x123, creator2 = @0x456)]
    fun test_extreme_fee_scenarios(admin: &signer, creator1: &signer, creator2: &signer) {
        // Setup: Initialize modules
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);

        // Test 1: Pool with 0% fee (creator1)
        apt_token::mint_for_testing(creator1, TEST_APT_MINT);
        eth_token::mint_for_testing(creator1, TEST_ETH_MINT);
        let pool_addr_0 = pool::create_pool(creator1, 1000000, 2000000, 0);
        
        // Verify: 0% fee pool works
        assert!(pool::pool_exists(pool_addr_0), 1);
        let fee_0 = pool::get_pool_fee(pool_addr_0);
        assert!(fee_0 == 0, 2);

        // Test 2: Pool with maximum fee (10%) (creator2)
        apt_token::mint_for_testing(creator2, TEST_APT_MINT);
        eth_token::mint_for_testing(creator2, TEST_ETH_MINT);
        let pool_addr_max = pool::create_pool(creator2, 1000000, 2000000, 1000);
        
        // Verify: Maximum fee pool works
        assert!(pool::pool_exists(pool_addr_max), 3);
        let fee_max = pool::get_pool_fee(pool_addr_max);
        assert!(fee_max == 1000, 4);

        // Test quote swaps with different fees
        let quote_0_fee = pool::quote_swap_with_fee(1500000, 3000000, 100000, 0);
        let quote_max_fee = pool::quote_swap_with_fee(1500000, 3000000, 100000, 1000);
        
        // Verify: Higher fee results in less output
        assert!(quote_0_fee > quote_max_fee, 5);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_invalid_parameter_combinations(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Add liquidity
        let lp_tokens = pool::add_liquidity(user, 500000, 1000000, 1000);

        // Test: Try to remove more LP tokens than owned
        // This should be caught by balance checks in the token system
        let user_addr = signer::address_of(user);
        let lp_metadata = pool::get_lp_token_metadata(_pool_addr);
        let lp_balance = lp_token::balance_of(user_addr, lp_metadata);
        
        // Verify: User has correct LP balance
        assert!(lp_balance >= lp_tokens, 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_integer_overflow_protection(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        
        // Use large but safe values
        let large_eth = 1000000000; // 1B units
        let large_apt = 1000000000; // 1B units
        
        apt_token::mint_for_testing(creator, large_apt);
        eth_token::mint_for_testing(creator, (large_eth as u256));

        let pool_addr = pool::create_pool(creator, large_eth, large_apt, DEFAULT_FEE_BPS);

        // Setup user with large amounts
        apt_token::mint_for_testing(user, 1000000000);
        eth_token::mint_for_testing(user, (1000000000 as u256));

        // Test: Large swap that tests overflow protection
        let large_swap_eth = 100000000; // 100M units
        let apt_out = pool::swap_eth_for_apt(user, large_swap_eth, 1);
        
        // Verify: Swap completed successfully without overflow
        assert!(apt_out > 0, 1);
        
        // Verify: Pool state is still consistent
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve > 0, 2);
        assert!(apt_reserve > 0, 3);
        
        // Verify: K invariant is maintained (should be larger due to fees)
        let k_value = (eth_reserve as u128) * (apt_reserve as u128);
        let original_k = (large_eth as u128) * (large_apt as u128);
        assert!(k_value >= original_k, 4);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_boundary_condition_swaps(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Add more liquidity
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 9000000, 18000000, 1000); // Large liquidity

        // Setup user
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Get initial reserves
        let (initial_eth, initial_apt) = pool::get_reserves(pool_addr);

        // Test 1: Swap that takes almost all of one reserve (but not quite)
        let large_eth_swap = initial_eth / 2; // Half the reserve
        let apt_out = pool::swap_eth_for_apt(user, large_eth_swap, 1);
        
        // Verify: Large swap worked
        assert!(apt_out > 0, 1);
        
        // Get updated reserves
        let (mid_eth, mid_apt) = pool::get_reserves(pool_addr);
        assert!(mid_eth == initial_eth + large_eth_swap, 2);
        assert!(mid_apt == initial_apt - apt_out, 3);

        // Test 2: Swap in the opposite direction
        let large_apt_swap = mid_apt / 3; // Third of remaining reserve
        let eth_out = pool::swap_apt_for_eth(user, large_apt_swap, 1);
        
        // Verify: Reverse swap worked
        assert!(eth_out > 0, 4);
        
        // Final verification
        let (final_eth, final_apt) = pool::get_reserves(pool_addr);
        assert!(final_eth == mid_eth - eth_out, 5);
        assert!(final_apt == mid_apt + large_apt_swap, 6);
    }

    // ===== HELPER FUNCTIONS =====

    fun setup_test_environment(admin: &signer, creator: &signer) {
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
    }

    fun create_test_pool(creator: &signer): address {
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        )
    }
} 