#[test_only]
module poseidon_swap::admin_governance_tests {
    use std::signer;
    use poseidon_swap::pool;
    use poseidon_swap::umi_token;
    use poseidon_swap::shell_token;
    use poseidon_swap::lp_token;

    // Test constants
    const TEST_UMI_MINT: u256 = 10000000; // 10 UMI for testing
    const TEST_SHELL_MINT: u64 = 20000000; // 20 Shell for testing
    const INITIAL_UMI_AMOUNT: u64 = 1000000; // 1 UMI
    const INITIAL_SHELL_AMOUNT: u64 = 2000000; // 2 Shell
    const DEFAULT_FEE_BPS: u64 = 30; // 0.3%

    // ===== TASK 5B.2: ADMIN & GOVERNANCE FUNCTIONS =====

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pause_unpause_pool(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Verify: Pool starts unpaused
        assert!(!pool::is_paused_for_testing(pool_addr), 1);

        // Test: Pause pool
        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 2);

        // Test: Unpause pool
        pool::resume_operations(creator, pool_addr);
        assert!(!pool::is_paused_for_testing(pool_addr), 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_fee_update(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Get initial fee
        let initial_fee = pool::get_pool_fee(pool_addr);
        assert!(initial_fee == DEFAULT_FEE_BPS, 1);

        // Test: Update fee to 0.5%
        pool::update_fee(creator, pool_addr, 50);
        let updated_fee = pool::get_pool_fee(pool_addr);
        assert!(updated_fee == 50, 2);

        // Test: Update fee to 0%
        pool::update_fee(creator, pool_addr, 0);
        let zero_fee = pool::get_pool_fee(pool_addr);
        assert!(zero_fee == 0, 3);

        // Test: Update fee to max (100%)
        pool::update_fee(creator, pool_addr, 10000);
        let max_fee = pool::get_pool_fee(pool_addr);
        assert!(max_fee == 10000, 4);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50)]
    fun test_unauthorized_fee_update(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to update fee as non-owner (should fail)
        pool::update_fee(user, pool_addr, 50);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 13)]
    fun test_invalid_fee_update(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to update fee above 100% (should fail)
        pool::update_fee(creator, pool_addr, 10001);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_emergency_stop(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Verify: Pool starts unpaused
        assert!(!pool::is_paused_for_testing(pool_addr), 1);

        // Test: Emergency stop
        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 2);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50)]
    fun test_unauthorized_emergency_stop(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to emergency stop as non-owner (should fail)
        pool::emergency_stop(user, pool_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_ownership_transfer(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let new_owner_addr = @0x789;

        // Test: Transfer ownership
        pool::transfer_ownership(creator, pool_addr, new_owner_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    #[expected_failure(abort_code = 16)]
    fun test_transfer_to_zero_address(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test: Try to transfer ownership to zero address (should fail)
        pool::transfer_ownership(creator, pool_addr, @0x0);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_transfer_to_self(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let creator_addr = signer::address_of(creator);

        // Test: Transfer ownership to self (should work)
        pool::transfer_ownership(creator, pool_addr, creator_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    #[expected_failure(abort_code = 50)]
    fun test_unauthorized_ownership_transfer(admin: &signer, creator: &signer, user: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        let new_owner_addr = @0x789;
        pool::transfer_ownership(user, pool_addr, new_owner_addr);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_governance_functions_sequence(admin: &signer, creator: &signer) {
        // Setup: Initialize and create pool
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // 1. Pause pool
        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 1);

        // 2. Update fee while paused
        pool::update_fee(creator, pool_addr, 50);
        let fee = pool::get_pool_fee(pool_addr);
        assert!(fee == 50, 2);

        // 3. Resume operations
        pool::resume_operations(creator, pool_addr);
        assert!(!pool::is_paused_for_testing(pool_addr), 3);

        // 4. Emergency stop again
        pool::emergency_stop(creator, pool_addr);
        assert!(pool::is_paused_for_testing(pool_addr), 5);
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