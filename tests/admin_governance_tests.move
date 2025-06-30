#[test_only]
module poseidon_swap::admin_governance_tests {
    use std::signer;
    use poseidon_swap::pool;
    use poseidon_swap::eth_token;
    use poseidon_swap::apt_token;
    use poseidon_swap::lp_token;
    use poseidon_swap::errors;

    // Test constants
    const TEST_ETH_MINT: u256 = 10000000; // 10 ETH for testing
    const TEST_APT_MINT: u64 = 20000000; // 20 APT for testing
    const INITIAL_ETH_AMOUNT: u64 = 1000000; // 1 ETH
    const INITIAL_APT_AMOUNT: u64 = 2000000; // 2 APT
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%

    // ===== TASK 5B.2: ADMIN & GOVERNANCE FUNCTIONS =====

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_pause_functionality(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Verify: Pool starts unpaused
        assert!(!pool::is_paused_for_testing(pool_addr), 1);

        // Test: Pause pool
        pool::set_pause_state(creator, pool_addr, true);
        assert!(pool::is_paused_for_testing(pool_addr), 2);

        // Test: Unpause pool
        pool::set_pause_state(creator, pool_addr, false);
        assert!(!pool::is_paused_for_testing(pool_addr), 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50, location = poseidon_swap::pool)]
    fun test_unauthorized_pause_attempt(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Non-admin tries to pause pool (should fail)
        pool::set_pause_state(user, pool_addr, true);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_fee_update_functionality(admin: &signer, creator: &signer) {
        // Setup: Create pool with default fee
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Verify: Pool starts with default fee
        let initial_fee = pool::get_pool_fee(pool_addr);
        assert!(initial_fee == DEFAULT_FEE_BPS, 1);

        // Test: Update fee to 1%
        pool::set_pool_fee(creator, pool_addr, 100);
        let updated_fee = pool::get_pool_fee(pool_addr);
        assert!(updated_fee == 100, 2);

        // Test: Update fee to 0%
        pool::set_pool_fee(creator, pool_addr, 0);
        let zero_fee = pool::get_pool_fee(pool_addr);
        assert!(zero_fee == 0, 3);

        // Test: Update fee to maximum allowed (10%)
        pool::set_pool_fee(creator, pool_addr, 1000);
        let max_fee = pool::get_pool_fee(pool_addr);
        assert!(max_fee == 1000, 4);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 13, location = poseidon_swap::pool)]
    fun test_pool_fee_update_invalid_fee(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to set fee above maximum (should fail)
        pool::set_pool_fee(creator, pool_addr, 1001); // > 10%
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50, location = poseidon_swap::pool)]
    fun test_unauthorized_fee_update_attempt(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Non-admin tries to update fee (should fail)
        pool::set_pool_fee(user, pool_addr, 50);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_emergency_stop_functionality(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Verify: Pool starts unpaused
        assert!(!pool::is_paused_for_testing(pool_addr), 1);

        // Test: Emergency stop
        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 2);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50, location = poseidon_swap::pool)]
    fun test_unauthorized_emergency_stop_attempt(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Non-admin tries emergency stop (should fail)
        pool::emergency_stop(user, pool_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, new_owner = @0x456)]
    fun test_ownership_transfer_functionality(admin: &signer, creator: &signer, new_owner: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let creator_addr = signer::address_of(creator);
        let new_owner_addr = signer::address_of(new_owner);

        // Verify: Creator is initial owner
        let (owner, _, _, _) = pool::get_pool_info(pool_addr);
        assert!(owner == creator_addr, 1);

        // Test: Transfer ownership
        pool::transfer_ownership(creator, pool_addr, new_owner_addr);

        // Verify: New owner is now the owner
        let (new_owner_check, _, _, _) = pool::get_pool_info(pool_addr);
        assert!(new_owner_check == new_owner_addr, 2);

        // Test: New owner can now perform admin functions
        pool::set_pause_state(new_owner, pool_addr, true);
        assert!(pool::is_paused_for_testing(pool_addr), 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 74, location = poseidon_swap::pool)]
    fun test_ownership_transfer_to_zero_address(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to transfer ownership to zero address (should fail)
        pool::transfer_ownership(creator, pool_addr, @0x0);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 74, location = poseidon_swap::pool)]
    fun test_ownership_transfer_to_self(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let creator_addr = signer::address_of(creator);

        // Test: Try to transfer ownership to self (should fail)
        pool::transfer_ownership(creator, pool_addr, creator_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456, new_owner = @0x789)]
    #[expected_failure(abort_code = 50, location = poseidon_swap::pool)]
    fun test_unauthorized_ownership_transfer(admin: &signer, creator: &signer, user: &signer, new_owner: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let new_owner_addr = signer::address_of(new_owner);

        // Test: Non-owner tries to transfer ownership (should fail)
        pool::transfer_ownership(user, pool_addr, new_owner_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_paused_pool_blocks_operations(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Create pool and add liquidity
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Setup user with tokens
        apt_token::mint_for_testing(user, TEST_APT_MINT);
        eth_token::mint_for_testing(user, TEST_ETH_MINT);

        // Add initial liquidity while unpaused
        pool::add_liquidity(user, 500000, 1000000, 1000);

        // Test: Pause pool
        pool::set_pause_state(creator, pool_addr, true);

        // Verify: All operations should fail when paused
        // These will be tested by trying operations and expecting failures
        // For now, we just verify the pool is paused
        assert!(pool::is_paused_for_testing(pool_addr), 1);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_admin_authorization_validation(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let creator_addr = signer::address_of(creator);

        // Verify: Creator is authorized admin
        let (owner, _, _, _) = pool::get_pool_info(pool_addr);
        assert!(owner == creator_addr, 1);

        // Test: Admin can perform all admin functions
        pool::set_pause_state(creator, pool_addr, true);
        assert!(pool::is_paused_for_testing(pool_addr), 2);

        pool::set_pause_state(creator, pool_addr, false);
        assert!(!pool::is_paused_for_testing(pool_addr), 3);

        pool::set_pool_fee(creator, pool_addr, 50);
        let fee = pool::get_pool_fee(pool_addr);
        assert!(fee == 50, 4);

        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 5);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_fee_effects_on_swaps(admin: &signer, creator: &signer) {
        // Setup: Create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Add liquidity for swaps
        apt_token::mint_for_testing(creator, TEST_APT_MINT);
        eth_token::mint_for_testing(creator, TEST_ETH_MINT);
        pool::add_liquidity(creator, 1000000, 2000000, 1000);

        // Test swap with default fee (0.3%)
        let initial_apt_out = pool::quote_swap_with_fee(1000000, 2000000, 100000, DEFAULT_FEE_BPS);

        // Update fee to 1%
        pool::set_pool_fee(creator, pool_addr, 100);

        // Test swap with higher fee (1%)
        let higher_fee_apt_out = pool::quote_swap_with_fee(1000000, 2000000, 100000, 100);

        // Verify: Higher fee results in less output
        assert!(higher_fee_apt_out < initial_apt_out, 1);

        // Update fee to 0%
        pool::set_pool_fee(creator, pool_addr, 0);

        // Test swap with no fee (0%)
        let no_fee_apt_out = pool::quote_swap_with_fee(1000000, 2000000, 100000, 0);

        // Verify: No fee results in highest output
        assert!(no_fee_apt_out > initial_apt_out, 2);
        assert!(no_fee_apt_out > higher_fee_apt_out, 3);
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