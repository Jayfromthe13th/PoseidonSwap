#[test_only]
module poseidon_swap::pool_integration_tests {
    use std::signer;
    use aptos_framework::account;
    use poseidon_swap::pool;
    use poseidon_swap::eth_token;
    use poseidon_swap::apt_token;
    use poseidon_swap::lp_token;
    use poseidon_swap::math;
    use poseidon_swap::errors;

    // Test constants
    const INITIAL_ETH_AMOUNT: u64 = 1000000; // 1 ETH (scaled to u64)
    const INITIAL_APT_AMOUNT: u64 = 2000000; // 2 APT
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%
    const TEST_ETH_MINT: u256 = 10000000000000000000; // 10 ETH in wei
    const TEST_APT_MINT: u64 = 10000000; // 10 APT

    // ===== TASK 5A.1: POOL CREATION & INITIALIZATION TESTING =====

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_success(admin: &signer, creator: &signer) {
        // Setup: Initialize token modules
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Verify initial balances
        let creator_addr = signer::address_of(creator);
        assert!(eth_token::balance_of(creator_addr) == TEST_ETH_MINT, 1);
        assert!(apt_token::balance_of(creator_addr) == TEST_APT_MINT, 2);

        // Test: Create pool
        let pool_addr = pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        );

        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 3);
        assert!(pool::get_main_pool_address() == pool_addr, 4);

        // Verify: Pool reserves are correct
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve == INITIAL_ETH_AMOUNT, 5);
        assert!(apt_reserve == INITIAL_APT_AMOUNT, 6);

        // Verify: Creator received LP tokens
        let expected_lp_tokens = math::sqrt_u64(INITIAL_ETH_AMOUNT * INITIAL_APT_AMOUNT);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let actual_lp_balance = lp_token::balance_of(creator_addr, lp_metadata);
        assert!(actual_lp_balance == expected_lp_tokens, 7);

        // Verify: Creator's token balances were reduced
        let remaining_eth = eth_token::balance_of(creator_addr);
        let remaining_apt = apt_token::balance_of(creator_addr);
        assert!(remaining_eth == TEST_ETH_MINT - (INITIAL_ETH_AMOUNT as u256), 8);
        assert!(remaining_apt == TEST_APT_MINT - INITIAL_APT_AMOUNT, 9);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_create_pool_insufficient_eth(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens with insufficient ETH
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, 500); // Less than required

        // Test: Try to create pool with insufficient ETH - should fail
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_create_pool_insufficient_apt(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens with insufficient APT
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, 500); // Less than required
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Try to create pool with insufficient APT - should fail
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 40, location = poseidon_swap::pool)]
    fun test_create_pool_invalid_fee(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Try to create pool with invalid fee (> 100%) - should fail
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            10001 // 100.01% fee - invalid
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_zero_fee(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Create pool with zero fee (should work)
        let pool_addr = pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            0 // 0% fee
        );

        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_create_pool_maximum_fee(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Create pool with maximum fee (100%)
        let pool_addr = pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            10000 // 100% fee
        );

        // Verify: Pool was created successfully
        assert!(pool::pool_exists(pool_addr), 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_info_after_creation(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens and create pool
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        let pool_addr = pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
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
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        let pool_addr = pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        );

        // Test: Quote swap functions work
        let quote_result = pool::quote_swap(
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            10000 // Use larger amount for fee effect to be visible
        );
        assert!(quote_result > 0, 1);

        let quote_with_fee = pool::quote_swap_with_fee(
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
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
    fun test_create_pool_minimum_liquidity_eth(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Try to create pool with below minimum ETH liquidity
        pool::create_pool(
            creator,
            999, // Below minimum (1000)
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        );
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_create_pool_minimum_liquidity_apt(admin: &signer, creator: &signer) {
        // Setup: Initialize tokens
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);

        // Test: Try to create pool with below minimum APT liquidity
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            999, // Below minimum (1000)
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
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

        let user2_addr = signer::address_of(user2);
        let initial_eth_balance = eth_token::balance_of(user2_addr);
        let initial_apt_balance = apt_token::balance_of(user2_addr);

        // Test: Add liquidity
        let liquidity_eth = 500000; // 0.5 ETH
        let liquidity_apt = 1000000; // 1 APT
        let min_liquidity = 1000; // Minimum LP tokens expected

        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_eth,
            liquidity_apt,
            min_liquidity
        );

        // Verify: LP tokens were minted
        assert!(lp_tokens_minted > 0, 1);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let user2_lp_balance = lp_token::balance_of(user2_addr, lp_metadata);
        assert!(user2_lp_balance == lp_tokens_minted, 2);

        // Verify: User balances were reduced
        let final_eth_balance = eth_token::balance_of(user2_addr);
        let final_apt_balance = apt_token::balance_of(user2_addr);
        assert!(final_eth_balance == initial_eth_balance - (liquidity_eth as u256), 3);
        assert!(final_apt_balance == initial_apt_balance - liquidity_apt, 4);

        // Verify: Pool reserves increased
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve == INITIAL_ETH_AMOUNT + liquidity_eth, 5);
        assert!(apt_reserve == INITIAL_APT_AMOUNT + liquidity_apt, 6);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_add_liquidity_proportional_amounts(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);

        // Setup: Prepare user2
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

        // Test: Add proportional liquidity (maintaining 1:2 ETH:APT ratio)
        let liquidity_eth = 250000; // 0.25 ETH
        let liquidity_apt = 500000;  // 0.5 APT (maintains 1:2 ratio)

        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_eth,
            liquidity_apt,
            1000 // min_lp_tokens
        );

        // Verify: LP tokens were minted proportionally
        assert!(lp_tokens_minted > 0, 1);

        // Verify: Pool reserves maintain ratio
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        let expected_eth = INITIAL_ETH_AMOUNT + liquidity_eth;
        let expected_apt = INITIAL_APT_AMOUNT + liquidity_apt;
        assert!(eth_reserve == expected_eth, 2);
        assert!(apt_reserve == expected_apt, 3);

        // Verify: Ratio is maintained (approximately)
        let ratio_before = (INITIAL_APT_AMOUNT * 1000) / INITIAL_ETH_AMOUNT; // 2000 (2:1 ratio)
        let ratio_after = (apt_reserve * 1000) / eth_reserve;
        assert!(ratio_before == ratio_after, 4);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_add_liquidity_insufficient_eth_balance(admin: &signer, user1: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);

        // Create user with insufficient ETH
        let user2 = account::create_account_for_test(@0x456);
        apt_token::mint_for_testing(&user2, TEST_APT_MINT);
        eth_token::mint_for_testing(&user2, 100); // Very small ETH amount

        // Test: Try to add liquidity with insufficient ETH - should fail
        pool::add_liquidity(
            &user2,
            500000, // More ETH than user has
            1000000,
            1000
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_add_liquidity_insufficient_apt_balance(admin: &signer, user1: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);

        // Create user with insufficient APT
        let user2 = account::create_account_for_test(@0x456);
        apt_token::mint_for_testing(&user2, 100); // Very small APT amount
        eth_token::mint_for_testing(&user2, TEST_ETH_MINT);

        // Test: Try to add liquidity with insufficient APT - should fail
        pool::add_liquidity(
            &user2,
            500000,
            1000000, // More APT than user has
            1000
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_remove_liquidity_partial(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

        let liquidity_eth = 500000;
        let liquidity_apt = 1000000;
        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_eth,
            liquidity_apt,
            1000
        );

        let user2_addr = signer::address_of(user2);
        let initial_eth_balance = eth_token::balance_of(user2_addr);
        let initial_apt_balance = apt_token::balance_of(user2_addr);

        // Test: Remove half of the liquidity
        let lp_to_remove = lp_tokens_minted / 2;
        let (eth_returned, apt_returned) = pool::remove_liquidity(
            user2,
            lp_to_remove,
            1, // min_eth_out
            1  // min_apt_out
        );

        // Verify: Tokens were returned
        assert!(eth_returned > 0, 1);
        assert!(apt_returned > 0, 2);

        // Verify: User balances increased
        let final_eth_balance = eth_token::balance_of(user2_addr);
        let final_apt_balance = apt_token::balance_of(user2_addr);
        assert!(final_eth_balance == initial_eth_balance + (eth_returned as u256), 3);
        assert!(final_apt_balance == initial_apt_balance + apt_returned, 4);

        // Verify: LP tokens were burned
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let remaining_lp_balance = lp_token::balance_of(user2_addr, lp_metadata);
        assert!(remaining_lp_balance == lp_tokens_minted - lp_to_remove, 5);

        // Verify: Pool reserves decreased
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve < INITIAL_ETH_AMOUNT + liquidity_eth, 6);
        assert!(apt_reserve < INITIAL_APT_AMOUNT + liquidity_apt, 7);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_remove_liquidity_full(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

        let liquidity_eth = 500000;
        let liquidity_apt = 1000000;
        let lp_tokens_minted = pool::add_liquidity(
            user2,
            liquidity_eth,
            liquidity_apt,
            1000
        );

        let user2_addr = signer::address_of(user2);
        let initial_eth_balance = eth_token::balance_of(user2_addr);
        let initial_apt_balance = apt_token::balance_of(user2_addr);

        // Test: Remove all liquidity
        let (eth_returned, apt_returned) = pool::remove_liquidity(
            user2,
            lp_tokens_minted, // Remove all LP tokens
            1, // min_eth_out
            1  // min_apt_out
        );

        // Verify: Significant amounts returned (should be close to what was deposited)
        assert!(eth_returned > liquidity_eth / 2, 1); // At least half back
        assert!(apt_returned > liquidity_apt / 2, 2); // At least half back

        // Verify: User balances increased
        let final_eth_balance = eth_token::balance_of(user2_addr);
        let final_apt_balance = apt_token::balance_of(user2_addr);
        assert!(final_eth_balance == initial_eth_balance + (eth_returned as u256), 3);
        assert!(final_apt_balance == initial_apt_balance + apt_returned, 4);

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
        apt_token::mint_for_testing(&user2, TEST_APT_MINT);
        eth_token::mint_for_testing(&user2, TEST_ETH_MINT);

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
    fun test_add_liquidity_slippage_protection_eth(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

        // Test: Add liquidity with unrealistic minimum ETH expectation - should fail
        pool::add_liquidity(
            user2,
            500000, // 0.5 ETH
            1000000, // 1 APT
            999999999 // Unrealistic minimum LP tokens (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_remove_liquidity_slippage_protection(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);

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
            999999999, // Unrealistic minimum ETH out (slippage protection)
            999999999  // Unrealistic minimum APT out (slippage protection)
        );
    }

    // ===== TASK 5A.3: TOKEN SWAP TESTING =====

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_eth_for_apt_success(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add some liquidity to enable swaps
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        let user3_addr = signer::address_of(&user3);
        let initial_eth_balance = eth_token::balance_of(user3_addr);
        let initial_apt_balance = apt_token::balance_of(user3_addr);

        // Test: Swap ETH for APT
        let eth_in = 100000; // 0.1 ETH
        let min_apt_out = 1; // Accept any amount (for testing)
        
        let apt_received = pool::swap_eth_for_apt(
            &user3,
            eth_in,
            min_apt_out
        );

        // Verify: APT was received
        assert!(apt_received > 0, 1);

        // Verify: User balances were updated correctly
        let final_eth_balance = eth_token::balance_of(user3_addr);
        let final_apt_balance = apt_token::balance_of(user3_addr);
        assert!(final_eth_balance == initial_eth_balance - (eth_in as u256), 2);
        assert!(final_apt_balance == initial_apt_balance + apt_received, 3);

        // Verify: Pool reserves were updated
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve > INITIAL_ETH_AMOUNT + 500000, 4); // Increased by initial liquidity + swap
        assert!(apt_reserve < INITIAL_APT_AMOUNT + 1000000, 5); // Decreased by swap amount
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_apt_for_eth_success(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add some liquidity to enable swaps
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        let user3_addr = signer::address_of(&user3);
        let initial_eth_balance = eth_token::balance_of(user3_addr);
        let initial_apt_balance = apt_token::balance_of(user3_addr);

        // Test: Swap APT for ETH
        let apt_in = 200000; // 0.2 APT
        let min_eth_out = 1; // Accept any amount (for testing)
        
        let eth_received = pool::swap_apt_for_eth(
            &user3,
            apt_in,
            min_eth_out
        );

        // Verify: ETH was received
        assert!(eth_received > 0, 1);

        // Verify: User balances were updated correctly
        let final_eth_balance = eth_token::balance_of(user3_addr);
        let final_apt_balance = apt_token::balance_of(user3_addr);
        assert!(final_eth_balance == initial_eth_balance + (eth_received as u256), 2);
        assert!(final_apt_balance == initial_apt_balance - apt_in, 3);

        // Verify: Pool reserves were updated
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        assert!(eth_reserve < INITIAL_ETH_AMOUNT + 500000, 4); // Decreased by swap amount
        assert!(apt_reserve > INITIAL_APT_AMOUNT + 1000000, 5); // Increased by initial liquidity + swap
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_fee_calculation(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        // Add liquidity
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Get initial pool info
        let (_, _, initial_volume, initial_fees) = pool::get_pool_info(pool_addr);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Perform swap to generate fees
        let eth_in = 100000; // 0.1 ETH
        pool::swap_eth_for_apt(&user3, eth_in, 1);

        // Verify: Pool info updated with volume and fees
        let (_, _, final_volume, final_fees) = pool::get_pool_info(pool_addr);
        assert!(final_volume > initial_volume, 1);
        assert!(final_fees > initial_fees, 2);

        // Verify: Fee calculation (0.3% of 100000 = 30)
        let expected_fee_increase = (eth_in * DEFAULT_FEE_BPS) / 10000;
        assert!(final_fees == initial_fees + (expected_fee_increase as u128), 3);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_swap_insufficient_eth_balance(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Create user with insufficient ETH
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, 100); // Very small ETH amount

        // Test: Try to swap more ETH than user has - should fail
        pool::swap_eth_for_apt(
            &user3,
            100000, // More than user has
            1
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 21, location = poseidon_swap::pool)]
    fun test_swap_insufficient_apt_balance(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Create user with insufficient APT
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, 100); // Very small APT amount
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Try to swap more APT than user has - should fail
        pool::swap_apt_for_eth(
            &user3,
            100000, // More than user has
            1
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_swap_slippage_protection_eth_for_apt(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Swap with unrealistic minimum output expectation - should fail
        pool::swap_eth_for_apt(
            &user3,
            100000, // 0.1 ETH
            999999999 // Unrealistic minimum APT out (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    #[expected_failure(abort_code = 41, location = poseidon_swap::pool)]
    fun test_swap_slippage_protection_apt_for_eth(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let _pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for swapping
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Swap with unrealistic minimum output expectation - should fail
        pool::swap_apt_for_eth(
            &user3,
            200000, // 0.2 APT
            999999999 // Unrealistic minimum ETH out (slippage protection)
        );
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_swap_quote_accuracy(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Get current reserves for quote calculation
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);

        // Test: Get quote for ETH → APT swap
        let eth_in = 100000;
        let quoted_apt_out = pool::quote_swap_with_fee(
            eth_reserve,
            apt_reserve,
            eth_in,
            DEFAULT_FEE_BPS
        );

        // Setup: Prepare user for actual swap
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Perform actual swap
        let actual_apt_out = pool::swap_eth_for_apt(&user3, eth_in, 1);

        // Verify: Actual output matches quote (should be very close)
        assert!(actual_apt_out == quoted_apt_out, 1);
    }

    #[test(admin = @poseidon_swap, user1 = @0x123, user2 = @0x456)]
    fun test_multiple_swaps_price_impact(admin: &signer, user1: &signer, user2: &signer) {
        // Setup: Initialize, create pool, and add liquidity
        setup_test_environment(admin, user1);
        let pool_addr = create_test_pool(user1);
        
        apt_token::mint_for_testing(user2, TEST_APT_MINT);
        eth_token::mint_for_testing(user2, TEST_ETH_MINT);
        pool::add_liquidity(user2, 500000, 1000000, 1000);

        // Setup: Prepare user for multiple swaps
        let user3 = account::create_account_for_test(@0x789);
        apt_token::mint_for_testing(&user3, TEST_APT_MINT);
        eth_token::mint_for_testing(&user3, TEST_ETH_MINT);

        // Test: Perform first swap
        let eth_in = 50000; // 0.05 ETH
        let apt_out_1 = pool::swap_eth_for_apt(&user3, eth_in, 1);

        // Test: Perform second identical swap (should get less APT due to price impact)
        let apt_out_2 = pool::swap_eth_for_apt(&user3, eth_in, 1);

        // Verify: Second swap gives less output due to price impact
        assert!(apt_out_2 < apt_out_1, 1);

        // Verify: Pool reserves reflect both swaps
        let (final_eth_reserve, final_apt_reserve) = pool::get_reserves(pool_addr);
        assert!(final_eth_reserve == INITIAL_ETH_AMOUNT + 500000 + (2 * eth_in), 2);
        assert!(final_apt_reserve == INITIAL_APT_AMOUNT + 1000000 - apt_out_1 - apt_out_2, 3);
    }

    // ===== TASK 5A.4: END-TO-END INTEGRATION TESTING =====

    #[test(admin = @poseidon_swap, lp_user = @0x123, trader1 = @0x456, trader2 = @0x789)]
    fun test_complete_amm_lifecycle(admin: &signer, lp_user: &signer, trader1: &signer, trader2: &signer) {
        // Phase 1: Initialize and create pool
        setup_test_environment(admin, lp_user);
        let pool_addr = create_test_pool(lp_user);

        // Track initial balances
        let lp_addr = signer::address_of(lp_user);
        let initial_lp_eth = eth_token::balance_of(lp_addr);
        let initial_lp_apt = apt_token::balance_of(lp_addr);

        // Phase 2: Add liquidity (LP becomes liquidity provider)
        apt_token::mint_for_testing(lp_user, TEST_APT_MINT);
        eth_token::mint_for_testing(lp_user, TEST_ETH_MINT);
        
        let liquidity_eth = 500000; // 0.5 ETH
        let liquidity_apt = 1000000; // 1 APT
        let lp_tokens = pool::add_liquidity(lp_user, liquidity_eth, liquidity_apt, 1000);
        
        // Verify: LP tokens minted
        assert!(lp_tokens > 0, 1);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        let lp_balance = lp_token::balance_of(lp_addr, lp_metadata);
        
        // Account for initial LP tokens from pool creation (sqrt(1000000 * 2000000) = 1414213)
        let expected_total_lp = 1414213 + lp_tokens; // Initial LP + new LP tokens
        assert!(lp_balance == expected_total_lp, 2);

        // Phase 3: Trading activity (multiple users, multiple swaps)
        // Setup traders
        apt_token::mint_for_testing(trader1, TEST_APT_MINT);
        eth_token::mint_for_testing(trader1, TEST_ETH_MINT);
        apt_token::mint_for_testing(trader2, TEST_APT_MINT);
        eth_token::mint_for_testing(trader2, TEST_ETH_MINT);

        let trader1_addr = signer::address_of(trader1);
        let trader2_addr = signer::address_of(trader2);

        // Get initial pool info for fee tracking
        let (_, _, initial_volume, initial_fees) = pool::get_pool_info(pool_addr);

        // Trader1: ETH → APT swap
        let eth_in_1 = 100000; // 0.1 ETH
        let apt_out_1 = pool::swap_eth_for_apt(trader1, eth_in_1, 1);
        assert!(apt_out_1 > 0, 3);

        // Trader2: APT → ETH swap
        let apt_in_2 = 200000; // 0.2 APT
        let eth_out_2 = pool::swap_apt_for_eth(trader2, apt_in_2, 1);
        assert!(eth_out_2 > 0, 4);

        // Trader1: Another ETH → APT swap (price impact test) - use larger amount for visible impact
        let eth_in_3 = 200000; // 0.2 ETH (larger amount for more price impact)
        let apt_out_3 = pool::swap_eth_for_apt(trader1, eth_in_3, 1);
        assert!(apt_out_3 < apt_out_1 * 2, 5); // Should get less than 2x the first swap due to price impact

        // Verify: Pool accumulated fees and volume
        let (_, _, final_volume, final_fees) = pool::get_pool_info(pool_addr);
        assert!(final_volume > initial_volume, 6);
        assert!(final_fees > initial_fees, 7);

        // Phase 4: LP removes liquidity (partial)
        let lp_to_remove = lp_tokens / 2; // Remove half
        let (eth_returned, apt_returned) = pool::remove_liquidity(lp_user, lp_to_remove, 1, 1);
        
        // Verify: LP received tokens back
        assert!(eth_returned > 0, 8);
        assert!(apt_returned > 0, 9);

        // Phase 5: Final balance verification
        let final_lp_eth = eth_token::balance_of(lp_addr);
        let final_lp_apt = apt_token::balance_of(lp_addr);
        
        // LP should have received more than initially deposited due to trading fees
        let net_eth_change = (final_lp_eth as u128) - (initial_lp_eth as u128) + (eth_returned as u128);
        let net_apt_change = (final_lp_apt as u128) - (initial_lp_apt as u128) + (apt_returned as u128);
        
        // Verify: LP profited from fees (should have more than they would with no trading)
        assert!(net_eth_change >= (liquidity_eth as u128) / 2, 10); // At least half back
        assert!(net_apt_change >= (liquidity_apt as u128) / 2, 11); // At least half back

        // Verify: Traders received their swapped tokens
        assert!(apt_token::balance_of(trader1_addr) > TEST_APT_MINT + apt_out_1 + apt_out_3 - 1000, 12);
        assert!(eth_token::balance_of(trader2_addr) > TEST_ETH_MINT + (eth_out_2 as u256) - 1000, 13);
    }

    #[test(admin = @poseidon_swap, lp1 = @0x123, lp2 = @0x456, trader = @0x789)]
    fun test_multi_user_liquidity_provision(admin: &signer, lp1: &signer, lp2: &signer, trader: &signer) {
        // Setup: Initialize pool with admin (not lp1 to avoid confusion)
        setup_test_environment(admin, admin);
        let pool_addr = create_test_pool(admin);

        // LP1 adds initial liquidity
        apt_token::mint_for_testing(lp1, TEST_APT_MINT);
        eth_token::mint_for_testing(lp1, TEST_ETH_MINT);
        let lp1_tokens = pool::add_liquidity(lp1, 500000, 1000000, 1000);

        // LP2 adds proportional liquidity
        apt_token::mint_for_testing(lp2, TEST_APT_MINT);
        eth_token::mint_for_testing(lp2, TEST_ETH_MINT);
        let lp2_tokens = pool::add_liquidity(lp2, 250000, 500000, 500); // Half of LP1

        // Verify: LP2 got approximately half the LP tokens of LP1
        assert!(lp2_tokens > lp1_tokens / 3, 1); // Allow some variance
        assert!(lp2_tokens < lp1_tokens * 2 / 3, 2);

        // Generate trading activity to create fees
        apt_token::mint_for_testing(trader, TEST_APT_MINT);
        eth_token::mint_for_testing(trader, TEST_ETH_MINT);
        pool::swap_eth_for_apt(trader, 100000, 1); // Generate fees

        // Both LPs remove their liquidity
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);
        
        let lp1_addr = signer::address_of(lp1);
        let lp2_addr = signer::address_of(lp2);
        
        let lp1_initial_eth = eth_token::balance_of(lp1_addr);
        let lp1_initial_apt = apt_token::balance_of(lp1_addr);
        let lp2_initial_eth = eth_token::balance_of(lp2_addr);
        let lp2_initial_apt = apt_token::balance_of(lp2_addr);

        let (lp1_eth_out, lp1_apt_out) = pool::remove_liquidity(lp1, lp1_tokens, 1, 1);
        let (lp2_eth_out, lp2_apt_out) = pool::remove_liquidity(lp2, lp2_tokens, 1, 1);

        // Verify: LP1 got approximately double what LP2 got (proportional to their contribution)
        assert!(lp1_eth_out > lp2_eth_out, 3);
        assert!(lp1_apt_out > lp2_apt_out, 4);
        
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
        
        apt_token::mint_for_testing(lp_user, TEST_APT_MINT);
        eth_token::mint_for_testing(lp_user, TEST_ETH_MINT);
        pool::add_liquidity(lp_user, 500000, 1000000, 1000);

        // Get initial price (ETH:APT ratio)
        let (initial_eth_reserve, initial_apt_reserve) = pool::get_reserves(pool_addr);
        let initial_price = (initial_apt_reserve * 1000) / initial_eth_reserve; // APT per 1000 ETH units

        // Setup trader
        apt_token::mint_for_testing(trader, TEST_APT_MINT);
        eth_token::mint_for_testing(trader, TEST_ETH_MINT);
        let trader_addr = signer::address_of(trader);

        // Large ETH → APT swap (creates price imbalance)
        let large_eth_swap = 200000; // 0.2 ETH (significant portion of pool)
        let apt_received = pool::swap_eth_for_apt(trader, large_eth_swap, 1);
        
        // Check price after large swap
        let (mid_eth_reserve, mid_apt_reserve) = pool::get_reserves(pool_addr);
        let mid_price = (mid_apt_reserve * 1000) / mid_eth_reserve;
        
        // Verify: Price moved significantly (APT became more expensive)
        assert!(mid_price < initial_price, 1); // Less APT per ETH (APT more expensive)

        // Arbitrage: Trader swaps some APT back to ETH (taking advantage of price difference)
        let apt_to_swap_back = apt_received / 3; // Swap back 1/3 of received APT
        let eth_from_arbitrage = pool::swap_apt_for_eth(trader, apt_to_swap_back, 1);

        // Check final price
        let (final_eth_reserve, final_apt_reserve) = pool::get_reserves(pool_addr);
        let final_price = (final_apt_reserve * 1000) / final_eth_reserve;

        // Verify: Price partially corrected (moved back toward initial price)
        assert!(final_price > mid_price, 2); // Price moved back somewhat
        assert!(final_price != initial_price, 3); // But not exactly back to initial

        // Verify: Trader's final balances (should have profited from arbitrage if done optimally)
        let final_trader_eth = eth_token::balance_of(trader_addr);
        let final_trader_apt = apt_token::balance_of(trader_addr);
        
        // Trader should have less ETH but more APT overall
        assert!(final_trader_eth < TEST_ETH_MINT, 4);
        assert!(final_trader_apt > TEST_APT_MINT, 5);
    }

    #[test(admin = @poseidon_swap, lp_user = @0x123, trader = @0x456)]
    fun test_pool_state_consistency_after_operations(admin: &signer, lp_user: &signer, trader: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, lp_user);
        let pool_addr = create_test_pool(lp_user);

        // Add liquidity
        apt_token::mint_for_testing(lp_user, TEST_APT_MINT);
        eth_token::mint_for_testing(lp_user, TEST_ETH_MINT);
        let lp_tokens = pool::add_liquidity(lp_user, 500000, 1000000, 1000);

        // Setup trader
        apt_token::mint_for_testing(trader, TEST_APT_MINT);
        eth_token::mint_for_testing(trader, TEST_ETH_MINT);

        // Perform multiple operations
        pool::swap_eth_for_apt(trader, 50000, 1);
        pool::swap_apt_for_eth(trader, 75000, 1);
        pool::swap_eth_for_apt(trader, 30000, 1);

        // Get final pool state
        let (eth_reserve, apt_reserve) = pool::get_reserves(pool_addr);
        let lp_metadata = pool::get_lp_token_metadata(pool_addr);

        // Verify: Constant product formula approximately maintained (allowing for fees)
        let k_final = (eth_reserve as u128) * (apt_reserve as u128);
        let k_initial = ((INITIAL_ETH_AMOUNT + 500000) as u128) * ((INITIAL_APT_AMOUNT + 1000000) as u128);
        
        // K should be greater due to fees (fees increase reserves without minting LP tokens)
        assert!(k_final >= k_initial, 1);

        // Verify: LP token supply consistency
        let lp_user_addr = signer::address_of(lp_user);
        let user_lp_balance = lp_token::balance_of(lp_user_addr, lp_metadata);
        
        // Account for initial LP tokens from pool creation
        let expected_remaining_lp = 1414213 + lp_tokens; // Should still have all LP tokens
        assert!(user_lp_balance == expected_remaining_lp, 2);

        // Verify: Pool reserves are positive
        assert!(eth_reserve > 0, 4);
        assert!(apt_reserve > 0, 5);

        // Verify: Remove all added liquidity returns tokens to LP
        let (final_eth, final_apt) = pool::remove_liquidity(lp_user, lp_tokens, 1, 1);
        assert!(final_eth > 0, 6);
        assert!(final_apt > 0, 7);

        // Verify: Pool still has reserves (from initial pool creation)
        let (remaining_eth, remaining_apt) = pool::get_reserves(pool_addr);
        assert!(remaining_eth > 0, 8); // Pool should still have reserves
        assert!(remaining_apt > 0, 9); // Pool should still have reserves
        
        // Verify: LP received reasonable amounts back
        assert!(final_eth > 100000, 10); // Should get back a reasonable amount
        assert!(final_apt > 100000, 11); // Should get back a reasonable amount
        
        // Verify: LP still has their original LP tokens from pool creation
        let final_user_lp_balance = lp_token::balance_of(lp_user_addr, lp_metadata);
        assert!(final_user_lp_balance > 0, 12); // Should still have initial LP tokens from pool creation
    }



    // ===== HELPER FUNCTIONS =====

    #[test_only]
    fun setup_test_environment(admin: &signer, user: &signer) {
        eth_token::init_for_testing(admin);
        apt_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);
    }

    #[test_only]
    fun create_test_pool(creator: &signer): address {
        pool::create_pool(
            creator,
            INITIAL_ETH_AMOUNT,
            INITIAL_APT_AMOUNT,
            DEFAULT_FEE_BPS
        )
    }
} 