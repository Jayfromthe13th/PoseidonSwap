#[test_only]
module poseidon_swap::pool_integration_tests {
    use std::signer;
    use aptos_framework::account;
    use poseidon_swap::pool;
    use poseidon_swap::umi_token;
    use poseidon_swap::shell_token;
    use poseidon_swap::lp_token;
    use poseidon_swap::math;

    // Test constants
    const INITIAL_UMI_AMOUNT: u64 = 1000000; // 1 UMI
    const INITIAL_SHELL_AMOUNT: u64 = 2000000; // 2 Shell
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%
    const TEST_UMI_MINT: u256 = 10000000; // 10 UMI
    const TEST_SHELL_MINT: u64 = 20000000; // 20 Shell

    // ===== TASK 5A.1: POOL CREATION & INITIALIZATION TESTING =====

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_success(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens and mint to creator
        setup_test_environment(admin, creator);
        
        let creator_addr = signer::address_of(creator);
        
        // Test: Create pool with initial liquidity
        let pool_addr = create_test_pool(creator);
        
        // Verify: Pool created at correct address
        assert!(pool_addr == creator_addr, 1);
        
        // Verify: Initial reserves set correctly
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == INITIAL_UMI_AMOUNT, 5);
        assert!(shell_reserve == INITIAL_SHELL_AMOUNT, 6);
        
        // Verify: Initial LP tokens minted correctly
        let expected_lp_tokens = math::sqrt_u64(INITIAL_UMI_AMOUNT * INITIAL_SHELL_AMOUNT);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let lp_balance = lp_token::balance_of(creator_addr, lp_metadata);
        assert!(lp_balance == expected_lp_tokens, 7);
        
        // Verify: Creator's remaining token balances
        let remaining_umi = umi_token::balance_of(creator_addr);
        let remaining_shell = shell_token::balance_of(creator_addr);
        assert!(remaining_umi == TEST_UMI_MINT - (INITIAL_UMI_AMOUNT as u256), 8);
        assert!(remaining_shell == TEST_SHELL_MINT - INITIAL_SHELL_AMOUNT, 9);
    }

    #[test(admin = @poseidon_swap, user = @0x123)]
    #[expected_failure(abort_code = 21)]  // insufficient_input_amount
    fun test_create_pool_insufficient_umi(admin: &signer, user: &signer) {
        // Setup: Initialize tokens with insufficient UMI
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(user, 500); // Less than required
        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        
        // Test: Try to create pool with insufficient UMI - should fail
        pool::create_pool(
            user,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS,
        );
    }

    #[test(admin = @poseidon_swap, user = @0x123)]
    #[expected_failure(abort_code = 21)]  // insufficient_input_amount
    fun test_create_pool_insufficient_shell(admin: &signer, user: &signer) {
        // Setup: Initialize tokens with insufficient Shell
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);
        shell_token::mint_for_testing(user, 500); // Less than required
        
        // Test: Try to create pool with insufficient Shell - should fail
        pool::create_pool(
            user,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS,
        );
    }

    #[test(admin = @poseidon_swap, user = @0x123)]
    #[expected_failure(abort_code = 40)]  // invalid_swap_amount
    fun test_create_pool_invalid_fee(admin: &signer, user: &signer) {
        // Setup: Initialize tokens
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);
        shell_token::mint_for_testing(user, TEST_SHELL_MINT);

        // Test: Try to create pool with invalid fee (> 100%) - should fail
        pool::create_pool(
            user,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            10001 // 100.01% fee - invalid
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_zero_fee(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        // Test: Create pool with zero fee (should work)
        let pool_addr = pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            0 // 0% fee
        );

        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_maximum_fee(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        // Test: Create pool with maximum fee (100%)
        let pool_addr = pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            10000 // 100% fee
        );

        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_info_after_creation(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens and create pool
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        let pool_addr = pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS
        );

        // Test: Get pool info
        let (creator_addr, created_at, total_volume, total_fees) = pool::get_pool_info(pool_addr);

        // Verify: Pool info is correct
        assert!(creator_addr == signer::address_of(creator), 1);
        assert!(created_at == 0, 2); // Mock implementation uses 0
        assert!(total_volume == 0, 3); // No swaps yet
        assert!(total_fees == 0, 4); // No fees collected yet
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_view_functions_after_pool_creation(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens and create pool
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        let pool_addr = pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS
        );

        // Test: Quote swap functions work
        let quote_result = pool::quote_swap(
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            10000 // Use larger amount for fee effect to be visible
        );
        assert!(quote_result > 0, 1);

        let quote_with_fee = pool::quote_swap_with_fee(
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            10000, // Use same larger amount
            DEFAULT_FEE_BPS
        );
        assert!(quote_with_fee < quote_result, 2); // With fee should be less
        assert!(quote_with_fee > 0, 3);

        // Test: Pool existence check
        assert!(pool::pool_exists(pool_addr), 4);
        assert!(!pool::pool_exists(@0x999), 5); // Non-existent pool
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_create_pool_minimum_liquidity_umi(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        // Test: Try to create pool with below minimum UMI liquidity
        pool::create_pool(
            creator,
            100, // Below minimum liquidity
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_create_pool_minimum_liquidity_shell(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);

        // Test: Try to create pool with below minimum Shell liquidity
        pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            100, // Below minimum liquidity
            DEFAULT_FEE_BPS
        );
    }

    // ===== TASK 5A.2: LIQUIDITY MANAGEMENT TESTING =====

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_add_initial_liquidity_success(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);

        // Setup: Prepare user2 for adding liquidity
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        let user2_addr = signer::address_of(user2);
        let initial_umi_balance = umi_token::balance_of(user2_addr);
        let initial_shell_balance = shell_token::balance_of(user2_addr);

        // Test: Add liquidity
        let liquidity_umi = 500000; // 0.5 UMI
        let liquidity_shell = 1000000; // 1 Shell
        let min_liquidity = 1000; // Minimum LP tokens expected

        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_umi,
            liquidity_shell,
            min_liquidity
        );

        // Verify: LP tokens were minted
        assert!(lp_tokens_minted > 0, 1);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let user2_lp_balance = lp_token::balance_of(user2_addr, lp_metadata);
        assert!(user2_lp_balance == lp_tokens_minted, 2);

        // Verify: User balances were reduced
        let final_umi_balance = umi_token::balance_of(user2_addr);
        let final_shell_balance = shell_token::balance_of(user2_addr);
        assert!(final_umi_balance == initial_umi_balance - (liquidity_umi as u256), 3);
        assert!(final_shell_balance == initial_shell_balance - liquidity_shell, 4);

        // Verify: Pool reserves increased
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == INITIAL_UMI_AMOUNT + liquidity_umi, 5);
        assert!(shell_reserve == INITIAL_SHELL_AMOUNT + liquidity_shell, 6);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_add_liquidity_proportional_amounts(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);

        // Setup: Prepare user2
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        // Test: Add proportional liquidity (maintaining 1:2 UMI:Shell ratio)
        let liquidity_umi = 250000; // 0.25 UMI
        let liquidity_shell = 500000;  // 0.5 Shell (maintains 1:2 ratio)

        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_umi,
            liquidity_shell,
            1000 // min_lp_tokens
        );

        // Verify: LP tokens were minted proportionally
        assert!(lp_tokens_minted > 0, 1);

        // Verify: Pool reserves maintain ratio
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        let expected_umi = INITIAL_UMI_AMOUNT + liquidity_umi;
        let expected_shell = INITIAL_SHELL_AMOUNT + liquidity_shell;
        assert!(umi_reserve == expected_umi, 2);
        assert!(shell_reserve == expected_shell, 3);

        // Verify: Ratio is maintained (approximately)
        let ratio_before = (INITIAL_SHELL_AMOUNT * 1000) / INITIAL_UMI_AMOUNT; // 2000 (2:1 ratio)
        let ratio_after = (shell_reserve * 1000) / umi_reserve;
        assert!(ratio_before == ratio_after, 4);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_add_liquidity_insufficient_umi_balance(admin: &signer, user1: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);

        // Create user with insufficient UMI
        let user2 = account::create_account_for_test(@0x456);
        shell_token::mint_for_testing(&user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user2, 100); // Very small UMI amount

        // Test: Try to add liquidity with insufficient UMI - should fail
        pool::add_liquidity(
            &user2,
            500000, // More UMI than user has
            1000000,
            1000
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_add_liquidity_insufficient_shell_balance(admin: &signer, user1: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);

        // Create user with insufficient Shell
        let user2 = account::create_account_for_test(@0x456);
        shell_token::mint_for_testing(&user2, 100); // Very small Shell amount
        umi_token::mint_for_testing(&user2, TEST_UMI_MINT);

        // Test: Try to add liquidity with insufficient Shell - should fail
        pool::add_liquidity(
            &user2,
            500000,
            1000000, // More Shell than user has
            1000
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_remove_liquidity_partial(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        let liquidity_umi = 500000;
        let liquidity_shell = 1000000;
        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_umi,
            liquidity_shell,
            1000
        );

        let user2_addr = signer::address_of(user2);
        let initial_umi_balance = umi_token::balance_of(user2_addr);
        let initial_shell_balance = shell_token::balance_of(user2_addr);

        // Test: Remove half of the liquidity
        let lp_to_remove = lp_tokens_minted / 2;
        let (umi_returned, shell_returned) = pool::remove_liquidity(
            user2,
            lp_to_remove,
            1, // min_umi_out
            1  // min_shell_out
        );

        // Verify: Tokens were returned
        assert!(umi_returned > 0, 1);
        assert!(shell_returned > 0, 2);

        // Verify: User balances increased
        let final_umi_balance = umi_token::balance_of(user2_addr);
        let final_shell_balance = shell_token::balance_of(user2_addr);
        assert!(final_umi_balance == initial_umi_balance + (umi_returned as u256), 3);
        assert!(final_shell_balance == initial_shell_balance + shell_returned, 4);

        // Verify: LP tokens were burned
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let remaining_lp_balance = lp_token::balance_of(user2_addr, lp_metadata);
        assert!(remaining_lp_balance == lp_tokens_minted - lp_to_remove, 5);

        // Verify: Pool reserves decreased
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve < INITIAL_UMI_AMOUNT + liquidity_umi, 6);
        assert!(shell_reserve < INITIAL_SHELL_AMOUNT + liquidity_shell, 7);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_remove_liquidity_full(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        let liquidity_umi = 500000;
        let liquidity_shell = 1000000;
        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_umi,
            liquidity_shell,
            1000
        );

        let user2_addr = signer::address_of(user2);
        let initial_umi_balance = umi_token::balance_of(user2_addr);
        let initial_shell_balance = shell_token::balance_of(user2_addr);

        // Test: Remove all liquidity
        let (umi_returned, shell_returned) = pool::remove_liquidity(
            user2,
            lp_tokens_minted, // Remove all LP tokens
            1, // min_umi_out
            1  // min_shell_out
        );

        // Verify: Significant amounts returned (should be close to what was deposited)
        assert!(umi_returned > liquidity_umi / 2, 1); // At least half back
        assert!(shell_returned > liquidity_shell / 2, 2); // At least half back

        // Verify: User balances increased
        let final_umi_balance = umi_token::balance_of(user2_addr);
        let final_shell_balance = shell_token::balance_of(user2_addr);
        assert!(final_umi_balance == initial_umi_balance + (umi_returned as u256), 3);
        assert!(final_shell_balance == initial_shell_balance + shell_returned, 4);

        // Verify: All LP tokens were burned
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let remaining_lp_balance = lp_token::balance_of(user2_addr, lp_metadata);
        assert!(remaining_lp_balance == 0, 5);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123)]
    #[expected_failure(abort_code = 23, location = poseidon_swap::pool)]
    fun test_remove_liquidity_insufficient_lp_tokens(admin: &signer, user1: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);

        // Create user with no LP tokens
        let user2 = account::create_account_for_test(@0x456);
        shell_token::mint_for_testing(&user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user2, TEST_UMI_MINT);

        // Test: Try to remove liquidity without having LP tokens - should fail
        pool::remove_liquidity(
            &user2,
            1000, // User has no LP tokens
            1,
            1
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_add_liquidity_slippage_protection_umi(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        // Test: Add liquidity with unrealistic minimum UMI expectation - should fail
        pool::add_liquidity(
            user2,
            500000, // 0.5 UMI
            1000000, // 1 Shell
            999999999 // Unrealistic minimum LP tokens (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_remove_liquidity_slippage_protection(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);

        let lp_tokens_minted = pool::add_liquidity(
            user2,
            500000,
            1000000,
            1000
        );

        // Test: Remove liquidity with unrealistic minimum output expectations - should fail
        pool::remove_liquidity(
            user2,
            lp_tokens_minted / 2,
            999999999, // Unrealistic minimum UMI out (slippage protection)
            999999999  // Unrealistic minimum Shell out (slippage protection)
        );
    }

    // ===== TASK 5A.3: TOKEN SWAP TESTING =====

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_umi_for_shell_success(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add some liquidity to enable swaps
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        let user3_addr = signer::address_of(&user3);
        let initial_umi_balance = umi_token::balance_of(user3_addr);
        let initial_shell_balance = shell_token::balance_of(user3_addr);

        // Test: Swap UMI for Shell
        let umi_in = 100000; // 0.1 UMI
        let min_shell_out = 0; // No slippage protection for test
        
        let shell_received = pool::swap_umi_for_shell(
            &user3,
            umi_in,
            min_shell_out
        );

        // Verify: Shell was received
        assert!(shell_received > 0, 1);

        // Verify: User balances were updated correctly
        let final_umi_balance = umi_token::balance_of(user3_addr);
        let final_shell_balance = shell_token::balance_of(user3_addr);
        assert!(final_umi_balance == initial_umi_balance - (umi_in as u256), 2);
        assert!(final_shell_balance == initial_shell_balance + shell_received, 3);

        // Verify: Pool reserves were updated
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve > INITIAL_UMI_AMOUNT + 500000, 4); // Increased by initial liquidity + swap
        assert!(shell_reserve < INITIAL_SHELL_AMOUNT + 1000000, 5); // Decreased by swap amount
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_shell_for_umi_success(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add some liquidity to enable swaps
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        let user3_addr = signer::address_of(&user3);
        let initial_umi_balance = umi_token::balance_of(user3_addr);
        let initial_shell_balance = shell_token::balance_of(user3_addr);

        // Test: Swap Shell for UMI
        let shell_in = 200000; // 0.2 Shell
        let min_umi_out = 0; // No slippage protection for test
        
        let umi_received = pool::swap_shell_for_umi(
            &user3,
            shell_in,
            min_umi_out
        );

        // Verify: UMI was received
        assert!(umi_received > 0, 1);

        // Verify: User balances were updated correctly
        let final_umi_balance = umi_token::balance_of(user3_addr);
        let final_shell_balance = shell_token::balance_of(user3_addr);
        assert!(final_umi_balance == initial_umi_balance + (umi_received as u256), 2);
        assert!(final_shell_balance == initial_shell_balance - shell_in, 3);

        // Verify: Pool reserves were updated
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve < INITIAL_UMI_AMOUNT + 500000, 4); // Decreased by swap amount
        assert!(shell_reserve > INITIAL_SHELL_AMOUNT + 1000000, 5); // Increased by initial liquidity + swap
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_fee_calculation(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add liquidity
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Get initial pool info
        let (_, _, initial_volume, initial_fees) = pool::get_pool_info(pool_addr);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Perform swap to generate fees
        let umi_in = 100000; // 0.1 UMI
        pool::swap_umi_for_shell(&user3, umi_in, 1);

        // Verify: Pool info updated with volume and fees
        let (_, _, final_volume, final_fees) = pool::get_pool_info(pool_addr);
        assert!(final_volume > initial_volume, 1);
        assert!(final_fees > initial_fees, 2);

        // Verify: Fee calculation (0.3% of 100000 = 30)
        let expected_fee_increase = (umi_in * DEFAULT_FEE_BPS) / 10000;
        assert!(final_fees == initial_fees + (expected_fee_increase as u128), 3);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 62, location = poseidon_swap::umi_token)]  // insufficient_balance
    fun test_swap_insufficient_umi_balance(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Create user with insufficient UMI
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, 100); // Very small UMI amount

        // Test: Try to swap more UMI than user has - should fail
        pool::swap_umi_for_shell(
            &user3,
            100000, // More than user has
            1
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 62, location = poseidon_swap::shell_token)]  // insufficient_balance
    fun test_swap_insufficient_shell_balance(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Create user with insufficient Shell
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, 100); // Very small Shell amount
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Try to swap more Shell than user has - should fail
        pool::swap_shell_for_umi(
            &user3,
            100000, // More than user has
            1
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_swap_slippage_protection_umi_for_shell(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Swap with unrealistic minimum output expectation - should fail
        pool::swap_umi_for_shell(
            &user3,
            100000, // 0.1 UMI
            999999999 // Unrealistic minimum Shell out (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_swap_slippage_protection_shell_for_umi(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Swap with unrealistic minimum output expectation - should fail
        pool::swap_shell_for_umi(
            &user3,
            200000, // 0.2 Shell
            999999999 // Unrealistic minimum UMI out (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_quote_accuracy(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Get current reserves for quote calculation
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);

        // Test: Get quote for UMI -> Shell swap
        let umi_in = 100000;
        let quoted_shell_out = pool::quote_swap_with_fee(
            umi_reserve,
            shell_reserve,
            umi_in,
            DEFAULT_FEE_BPS
        );

        // Setup: Prepare user for actual swap
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Perform actual swap
        let actual_shell_out = pool::swap_umi_for_shell(&user3, umi_in, 1);

        // Verify: Actual output matches quote (should be very close)
        assert!(actual_shell_out == quoted_shell_out, 1);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_multiple_swaps_price_impact(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        shell_token::mint_for_testing(user2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user2, TEST_UMI_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for multiple swaps
        let user3 = account::create_account_for_test(@0x789);
        shell_token::mint_for_testing(&user3, TEST_SHELL_MINT);
        umi_token::mint_for_testing(&user3, TEST_UMI_MINT);

        // Test: Perform first swap
        let umi_in = 50000; // 0.05 UMI
        let shell_out_1 = pool::swap_umi_for_shell(&user3, umi_in, 1);

        // Test: Perform second identical swap (should get less Shell due to price impact)
        let shell_out_2 = pool::swap_umi_for_shell(&user3, umi_in, 1);

        // Verify: Second swap gives less output due to price impact
        assert!(shell_out_2 < shell_out_1, 1);

        // Verify: Pool reserves reflect both swaps
        let (final_umi_reserve, final_shell_reserve) = pool::get_reserves(pool_addr);
        assert!(final_umi_reserve == INITIAL_UMI_AMOUNT + 500000 + (2 * umi_in), 2);
        assert!(final_shell_reserve == INITIAL_SHELL_AMOUNT + 1000000 - shell_out_1 - shell_out_2, 3);
    }

    // ===== TASK 5A.4: END-TO-END INTEGRATION TESTING =====

    #[test(admin = @poseidon_swap, lp_user = @0x123, trader1 = @0x456, trader2 = @0x789)]
    fun test_complete_amm_lifecycle(admin: &signer, lp_user: &signer, trader1: &signer, trader2: &signer) {
        // Phase 1: Initialize and create pool
        setup_test_environment(admin, lp_user);
        let pool_addr = create_test_pool(lp_user);

        // Track initial balances
        let lp_addr = signer::address_of(lp_user);
        let initial_lp_umi = umi_token::balance_of(lp_addr);
        let initial_lp_shell = shell_token::balance_of(lp_addr);

        // Phase 2: Add liquidity (LP becomes liquidity provider)
        shell_token::mint_for_testing(lp_user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(lp_user, TEST_UMI_MINT);
        
        let liquidity_umi = 500000; // 0.5 UMI
        let liquidity_shell = 1000000; // 1 Shell
        let lp_tokens = pool::add_liquidity(lp_user, liquidity_umi, liquidity_shell, 1000);
        
        // Verify: LP tokens minted
        assert!(lp_tokens > 0, 1);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let lp_balance = lp_token::balance_of(lp_addr, lp_metadata);
        
        // Account for initial LP tokens from pool creation (sqrt(1000000 * 2000000) = 1414213)
        let expected_total_lp = 1414213 + lp_tokens; // Initial LP + new LP tokens
        assert!(lp_balance == expected_total_lp, 2);

        // Phase 3: Trading activity (multiple users, multiple swaps)
        // Setup traders
        shell_token::mint_for_testing(trader1, TEST_SHELL_MINT);
        umi_token::mint_for_testing(trader1, TEST_UMI_MINT);
        shell_token::mint_for_testing(trader2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(trader2, TEST_UMI_MINT);

        let trader1_addr = signer::address_of(trader1);
        let trader2_addr = signer::address_of(trader2);

        // Get initial pool info for fee tracking
        let (_, _, initial_volume, initial_fees) = pool::get_pool_info(pool_addr);

        // Trader1: UMI -> Shell swap
        let umi_in_1 = 100000; // 0.1 UMI
        let shell_out_1 = pool::swap_umi_for_shell(trader1, umi_in_1, 1);
        assert!(shell_out_1 > 0, 3);

        // Trader2: Shell -> UMI swap
        let shell_in_2 = 200000; // 0.2 Shell
        let umi_out_2 = pool::swap_shell_for_umi(trader2, shell_in_2, 1);
        assert!(umi_out_2 > 0, 4);

        // Trader1: Another UMI Shell swap (price impact test) - use larger amount for visible impact
        let umi_in_3 = 200000; // 0.2 UMI (larger amount for more price impact)
        let shell_out_3 = pool::swap_umi_for_shell(trader1, umi_in_3, 1);
        assert!(shell_out_3 < shell_out_1 * 2, 5); // Should get less than 2x the first swap due to price impact

        // Verify: Pool accumulated fees and volume
        let (_, _, final_volume, final_fees) = pool::get_pool_info(pool_addr);
        assert!(final_volume > initial_volume, 6);
        assert!(final_fees > initial_fees, 7);

        // Phase 4: LP removes liquidity (partial)
        let lp_to_remove = lp_tokens / 2; // Remove half
        let (umi_returned, shell_returned) = pool::remove_liquidity(lp_user, lp_to_remove, 1, 1);
        
        // Verify: LP received tokens back
        assert!(umi_returned > 0, 8);
        assert!(shell_returned > 0, 9);

        // Phase 5: Final balance verification
        let final_lp_umi = umi_token::balance_of(lp_addr);
        let final_lp_shell = shell_token::balance_of(lp_addr);
        
        // LP should have received more than initially deposited due to trading fees
        let net_umi_change = (final_lp_umi as u128) - (initial_lp_umi as u128) + (umi_returned as u128);
        let net_shell_change = (final_lp_shell as u128) - (initial_lp_shell as u128) + (shell_returned as u128);
        
        // Verify: LP profited from fees (should have more than they would with no trading)
        assert!(net_umi_change >= (liquidity_umi as u128) / 2, 10); // At least half back
        assert!(net_shell_change >= (liquidity_shell as u128) / 2, 11); // At least half back

        // Verify: Traders received their swapped tokens
        assert!(shell_token::balance_of(trader1_addr) > TEST_SHELL_MINT + shell_out_1 + shell_out_3 - 1000, 12);
        assert!(umi_token::balance_of(trader2_addr) > TEST_UMI_MINT + (umi_out_2 as u256) - 1000, 13);
    }

    #[test(admin = @poseidon_swap, lp1 = @0x123, lp2 = @0x456, trader = @0x789)]
    fun test_multi_user_liquidity_provision(admin: &signer, lp1: &signer, lp2: &signer, trader: &signer) {
        // Setup: Initialize pool with admin (not lp1 to avoid confusion)
        setup_test_environment(admin, admin);
        let pool_addr = create_test_pool(admin);

        // LP1 adds initial liquidity
        shell_token::mint_for_testing(lp1, TEST_SHELL_MINT);
        umi_token::mint_for_testing(lp1, TEST_UMI_MINT);
        let lp1_tokens = pool::add_liquidity(lp1, 500000, 1000000, 1000);

        // LP2 adds proportional liquidity
        shell_token::mint_for_testing(lp2, TEST_SHELL_MINT);
        umi_token::mint_for_testing(lp2, TEST_UMI_MINT);
        let lp2_tokens = pool::add_liquidity(lp2, 250000, 500000, 500); // Half of LP1

        // Verify: LP2 got approximately half the LP tokens of LP1
        assert!(lp2_tokens > lp1_tokens / 3, 1); // Allow some variance
        assert!(lp2_tokens < lp1_tokens * 2 / 3, 2);

        // Generate trading activity to create fees
        shell_token::mint_for_testing(trader, TEST_SHELL_MINT);
        umi_token::mint_for_testing(trader, TEST_UMI_MINT);
        pool::swap_umi_for_shell(trader, 100000, 1); // Generate fees

        // Both LPs remove their liquidity
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        
        let lp1_addr = signer::address_of(lp1);
        let lp2_addr = signer::address_of(lp2);

        let (lp1_umi_out, lp1_shell_out) = pool::remove_liquidity(lp1, lp1_tokens, 1, 1);
        let (lp2_umi_out, lp2_shell_out) = pool::remove_liquidity(lp2, lp2_tokens, 1, 1);

        // Verify: LP1 got approximately double what LP2 got (proportional to their contribution)
        assert!(lp1_umi_out > lp2_umi_out, 3);
        assert!(lp1_shell_out > lp2_shell_out, 4);
        
        // Verify: Both LPs have no remaining LP tokens
        let lp1_remaining = lp_token::balance_of(lp1_addr, lp_metadata);
        let lp2_remaining = lp_token::balance_of(lp2_addr, lp_metadata);
        assert!(lp1_remaining == 0, 5);
        assert!(lp2_remaining == 0, 6);
    }

    #[test(admin = @poseidon_swap, lp_user = @0x123, trader = @0x456)]
    fun test_arbitrage_opportunity_and_price_correction(admin: &signer, lp_user: &signer, trader: &signer) {
        // Setup: Create pool with initial liquidity
        setup_test_environment(admin, lp_user);
        let pool_addr = create_test_pool(lp_user);
        
        shell_token::mint_for_testing(lp_user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(lp_user, TEST_UMI_MINT);
        pool::add_liquidity(lp_user, 500000, 1000000, 1000);

        // Get initial price (UMI:Shell ratio)
        let (initial_umi_reserve, initial_shell_reserve) = pool::get_reserves(pool_addr);
        let initial_price = (initial_shell_reserve * 1000) / initial_umi_reserve; // Shell per 1000 UMI units

        // Setup trader
        shell_token::mint_for_testing(trader, TEST_SHELL_MINT);
        umi_token::mint_for_testing(trader, TEST_UMI_MINT);
        let trader_addr = signer::address_of(trader);

        // Large UMI Shell swap (creates price imbalance)
        let large_umi_swap = 200000; // 0.2 UMI (significant portion of pool)
        let shell_received = pool::swap_umi_for_shell(trader, large_umi_swap, 1);
        
        // Check price after large swap
        let (mid_umi_reserve, mid_shell_reserve) = pool::get_reserves(pool_addr);
        let mid_price = (mid_shell_reserve * 1000) / mid_umi_reserve;
        
        // Verify: Price moved significantly (Shell became more expensive)
        assert!(mid_price < initial_price, 1); // Less Shell per UMI (Shell more expensive)

        // Arbitrage: Trader swaps some Shell back to UMI (taking advantage of price difference)
        let shell_to_swap_back = shell_received / 3; // Swap back 1/3 of received Shell
        let _umi_from_arbitrage = pool::swap_shell_for_umi(trader, shell_to_swap_back, 1);

        // Check final price
        let (final_umi_reserve, final_shell_reserve) = pool::get_reserves(pool_addr);
        let final_price = (final_shell_reserve * 1000) / final_umi_reserve;

        // Verify: Price partially corrected (moved back toward initial price)
        assert!(final_price > mid_price, 2); // Price moved back somewhat
        assert!(final_price != initial_price, 3); // But not exactly back to initial

        // Verify: Trader's final balances (should have profited from arbitrage if done optimally)
        let final_trader_umi = umi_token::balance_of(trader_addr);
        let final_trader_shell = shell_token::balance_of(trader_addr);
        
        // Trader should have less UMI but more Shell overall
        assert!(final_trader_umi < TEST_UMI_MINT, 4);
        assert!(final_trader_shell > TEST_SHELL_MINT, 5);
    }

    #[test(admin = @poseidon_swap, lp_user = @0x123, trader = @0x456)]
    fun test_pool_state_consistency_after_operations(admin: &signer, lp_user: &signer, trader: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, lp_user);
        let pool_addr = create_test_pool(lp_user);

        // Add liquidity
        shell_token::mint_for_testing(lp_user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(lp_user, TEST_UMI_MINT);
        let lp_tokens = pool::add_liquidity(lp_user, 500000, 1000000, 1000);

        // Setup trader
        shell_token::mint_for_testing(trader, TEST_SHELL_MINT);
        umi_token::mint_for_testing(trader, TEST_UMI_MINT);

        // Perform multiple operations
        pool::swap_umi_for_shell(trader, 50000, 1);
        pool::swap_shell_for_umi(trader, 75000, 1);
        pool::swap_umi_for_shell(trader, 30000, 1);

        // Get final pool state
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);

        // Verify: Constant product formula approximately maintained (allowing for fees)
        let k_final = (umi_reserve as u128) * (shell_reserve as u128);
        let k_initial = ((INITIAL_UMI_AMOUNT + 500000) as u128) * ((INITIAL_SHELL_AMOUNT + 1000000) as u128);
        
        // K should be greater due to fees (fees increase reserves without minting LP tokens)
        assert!(k_final >= k_initial, 1);

        // Verify: LP token supply consistency
        let lp_user_addr = signer::address_of(lp_user);
        let user_lp_balance = lp_token::balance_of(lp_user_addr, lp_metadata);
        
        // Account for initial LP tokens from pool creation
        let expected_remaining_lp = 1414213 + lp_tokens; // Should still have all LP tokens
        assert!(user_lp_balance == expected_remaining_lp, 2);

        // Verify: Pool reserves are positive
        assert!(umi_reserve > 0, 4);
        assert!(shell_reserve > 0, 5);

        // Verify: Remove all added liquidity returns tokens to LP
        let (final_umi, final_shell) = pool::remove_liquidity(lp_user, lp_tokens, 1, 1);
        assert!(final_umi > 0, 6);
        assert!(final_shell > 0, 7);

        // Verify: Pool still has reserves (from initial pool creation)
        let (remaining_umi, remaining_shell) = pool::get_reserves(pool_addr);
        assert!(remaining_umi > 0, 8); // Pool should still have reserves
        assert!(remaining_shell > 0, 9); // Pool should still have reserves
        
        // Verify: LP received reasonable amounts back
        assert!(final_umi > 100000, 10); // Should get back a reasonable amount
        assert!(final_shell > 100000, 11); // Should get back a reasonable amount
        
        // Verify: LP still has their original LP tokens from pool creation
        let final_user_lp_balance = lp_token::balance_of(lp_user_addr, lp_metadata);
        assert!(final_user_lp_balance > 0, 12); // Should still have initial LP tokens from pool creation
    }

    // ===== HELPER FUNCTIONS =====

    fun setup_test_environment(admin: &signer, creator: &signer) {
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        
        shell_token::mint_for_testing(creator, TEST_SHELL_MINT);
        umi_token::mint_for_testing(creator, TEST_UMI_MINT);
    }

    fun create_test_pool(creator: &signer): address {
        pool::create_pool(
            creator,
            INITIAL_UMI_AMOUNT,
            INITIAL_SHELL_AMOUNT,
            DEFAULT_FEE_BPS
        )
    }
} 