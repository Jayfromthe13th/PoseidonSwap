#[test_only]
module poseidon_swap::event_system_tests {
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
        umi_token::init_for_testing(admin);
        shell_token::init_for_testing(admin);
        pool::init_for_testing(admin);
        lp_token::init_for_testing(admin);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_creation_event(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);
        
        shell_token::mint_for_testing(creator, INITIAL_SHELL_AMOUNT);
        umi_token::mint_for_testing(creator, (INITIAL_UMI_AMOUNT as u256));

        let pool_addr = pool::create_pool(creator, INITIAL_UMI_AMOUNT, INITIAL_SHELL_AMOUNT, DEFAULT_FEE_BPS);
        
        assert!(pool::pool_exists(pool_addr), 1);
        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == INITIAL_UMI_AMOUNT, 2);
        assert!(shell_reserve == INITIAL_SHELL_AMOUNT, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_liquidity_events(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Add liquidity
        let liquidity_umi = 500000u64;
        let liquidity_shell = 1000000u64;
        
        shell_token::mint_for_testing(user, liquidity_shell);
        umi_token::mint_for_testing(user, (liquidity_umi as u256));

        pool::add_liquidity(user, liquidity_umi, liquidity_shell, 1000);

        let (umi_reserve, shell_reserve) = pool::get_reserves(pool_addr);
        assert!(umi_reserve == INITIAL_UMI_AMOUNT + liquidity_umi, 4);
        assert!(shell_reserve == INITIAL_SHELL_AMOUNT + liquidity_shell, 5);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_swap_events(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        // Setup user
        let umi_in = 100000u64;
        shell_token::mint_for_testing(user, TEST_SHELL_MINT);
        umi_token::mint_for_testing(user, (umi_in as u256));

        // Track initial balances
        let initial_umi_balance = umi_token::balance_of(signer::address_of(user));
        let initial_shell_balance = shell_token::balance_of(signer::address_of(user));

        // Perform swap
        let shell_out = pool::swap_umi_for_shell(user, umi_in, 1);

        // Check balances after swap
        let final_umi_balance = umi_token::balance_of(signer::address_of(user));
        let final_shell_balance = shell_token::balance_of(signer::address_of(user));

        // Verify balance changes
        assert!(final_umi_balance == initial_umi_balance - (umi_in as u256), 2);
        assert!(final_shell_balance == initial_shell_balance + shell_out, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123, user = @0x456)]
    fun test_swap_shell_for_umi_events(admin: &signer, creator: &signer, user: &signer) {
        setup_test_environment(admin, creator);
        let _pool_addr = create_test_pool(creator);

        // Setup user
        let shell_in = 200000u64;
        shell_token::mint_for_testing(user, shell_in);
        umi_token::mint_for_testing(user, TEST_UMI_MINT);

        // Track initial balances
        let initial_umi_balance = umi_token::balance_of(signer::address_of(user));
        let initial_shell_balance = shell_token::balance_of(signer::address_of(user));

        // Perform swap
        let umi_received = pool::swap_shell_for_umi(user, shell_in, 1);

        // Check balances after swap
        let final_umi_balance = umi_token::balance_of(signer::address_of(user));
        let final_shell_balance = shell_token::balance_of(signer::address_of(user));

        // Verify balance changes
        assert!(final_umi_balance == initial_umi_balance + (umi_received as u256), 2);
        assert!(final_shell_balance == initial_shell_balance - shell_in, 3);
    }

    #[test(admin = @poseidon_swap, creator = @0x123)]
    fun test_pool_pause_events(admin: &signer, creator: &signer) {
        setup_test_environment(admin, creator);
        let pool_addr = create_test_pool(creator);

        // Test pause
        pool::set_pause_state(creator, pool_addr, true);
        assert!(pool::is_paused(pool_addr), 1);

        // Test unpause
        pool::set_pause_state(creator, pool_addr, false);
        assert!(!pool::is_paused(pool_addr), 2);
    }
} 