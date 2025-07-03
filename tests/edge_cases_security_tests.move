#[test_only]
module poseidon_swap::edge_cases_security_tests {
    use poseidon_swap::pool;
    use poseidon_swap::umi_token;
    use poseidon_swap::shell_token;
    use poseidon_swap::lp_token;
    use poseidon_swap::math;
    use aptos_framework::account;

    // Test constants
    const TEST_UMI_MINT: u256 = 10000000; // 10 UMI for testing
    const TEST_SHELL_MINT: u64 = 20000000; // 20 Shell for testing
    const INITIAL_UMI_AMOUNT: u64 = 1000000; // 1 UMI
    const INITIAL_SHELL_AMOUNT: u64 = 2000000; // 2 Shell
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%

    // Helper function to create test pool
    fun create_test_pool(creator: &signer): address {
        // Mint initial tokens
        shell_token::mint_for_testing(creator, INITIAL_SHELL_AMOUNT);
        umi_token::mint_for_testing(creator, (INITIAL_UMI_AMOUNT as u256));
        
        // Create pool
        pool::create_pool(creator, INITIAL_UMI_AMOUNT, INITIAL_SHELL_AMOUNT, DEFAULT_FEE_BPS)
    }

    // Helper function to setup test environment
    fun setup_test_environment(admin: &signer, _creator: &signer) {
        pool::init_for_testing(admin);
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        lp_token::init_for_testing(admin);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_umi_pool_creation(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);
        pool::create_pool(creator, 0, INITIAL_SHELL_AMOUNT, DEFAULT_FEE_BPS);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_shell_pool_creation(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);
        pool::create_pool(creator, INITIAL_UMI_AMOUNT, 0, DEFAULT_FEE_BPS);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_umi_liquidity_addition(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);

        pool::add_liquidity(user, 0, 1000000, 1000);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_zero_shell_liquidity_addition(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);

        pool::add_liquidity(user, 1000000, 0, 1000);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_maximum_value_operations(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);

        let large_umi = 1000000000u64; // 1B units
        let large_shell = 2000000000u64; // 2B units
        
        shell_token::mint_for_testing(creator, large_shell);
        umi_token::mint_for_testing(creator, (large_umi as u256));

        let pool_addr = pool::create_pool(creator, large_umi, large_shell, DEFAULT_FEE_BPS);
        
        assert!(pool::pool_exists(pool_addr), 1);
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == large_umi, 2);
        assert!(shell_reserve == large_shell, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_minimum_viable_amounts(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);

        let min_umi = 1000u64; // Minimum UMI (0.001 UMI)
        let min_shell = 1000u64; // Minimum Shell (0.001 Shell)
        
        shell_token::mint_for_testing(creator, min_shell);
        umi_token::mint_for_testing(creator, (min_umi as u256));

        let pool_addr = pool::create_pool(creator, min_umi, min_shell, DEFAULT_FEE_BPS);
        
        assert!(pool::pool_exists(pool_addr), 1);
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == min_umi, 2);
        assert!(shell_reserve == min_shell, 3);

        let expected_lp = math::sqrt_u64(min_umi * min_shell);
        assert!(expected_lp > 0, 4);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_precision_loss_scenarios(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        
        let small_umi = 10000u64; // Above MIN_LIQUIDITY (1000)
        let small_shell = 20000u64; // Above MIN_LIQUIDITY (1000)
        
        shell_token::mint_for_testing(creator, small_shell);
        umi_token::mint_for_testing(creator, (small_umi as u256));

        let pool_addr = pool::create_pool(creator, small_umi, small_shell, DEFAULT_FEE_BPS);

        shell_token::mint_for_testing(user, 1000);
        umi_token::mint_for_testing(user, 1000);

        let tiny_umi_in = 1u64; // 1 unit UMI
        let shell_out = pool::swap_umi_for_shell(user, tiny_umi_in, 1);
        
        assert!(shell_out >= 1, 1);

        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == small_umi + tiny_umi_in, 2);
        assert!(shell_reserve == small_shell - shell_out, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_rounding_error_accumulation(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        pool::add_liquidity(creator, 5000000, 10000000, 1000);

        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);

        let (initial_umi, initial_shell) = pool::get_reserves(pool_addr);
        let initial_k = (initial_umi as u128) * (initial_shell as u128);

        pool::swap_umi_for_shell(user, 1000, 1);
        pool::swap_shell_for_umi(user, 2000, 1);
        pool::swap_umi_for_shell(user, 1000, 1);
        pool::swap_shell_for_umi(user, 2000, 1);
        pool::swap_umi_for_shell(user, 1000, 1);
        pool::swap_shell_for_umi(user, 2000, 1);
        pool::swap_umi_for_shell(user, 1000, 1);
        pool::swap_shell_for_umi(user, 2000, 1);
        pool::swap_umi_for_shell(user, 1000, 1);
        pool::swap_shell_for_umi(user, 2000, 1);

        let (final_umi, final_shell) = pool::get_reserves(pool_addr);
        let final_k = (final_umi as u128) * (final_shell as u128);

        assert!(final_k >= initial_k, 1);
        
        let umi_ratio = if (final_umi > initial_umi) {
            (final_umi * 100) / initial_umi
        } else {
            (initial_umi * 100) / final_umi
        };
        assert!(umi_ratio <= 110, 2); // Within 10% variance
    }

    #[test(admin = @poseidon_swap, user = @0x123)]
    #[expected_failure(abort_code = 41)]  // slippage_exceeded
    fun test_excessive_slippage_umi_swap(admin: &signer, user: &signer) {
        // Setup: Initialize and create pool
        let creator = account::create_account_for_test(@0x123);
        setup_test_environment(admin, &creator);
        let _pool_addr = create_test_pool(&creator);
        
        shell_token::mint_for_testing(admin, TEST_SHELL_MINT);
        umi_token::mint_for_testing(admin, TEST_UMI_MINT);
        pool::add_liquidity(admin, 1000000, 2000000, 1000);

        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);

        pool::swap_umi_for_shell(user, 100000, 1000000); // Expect way more than possible
    }
} 