/// Shell Token Mock Module
/// Provides simple Shell token operations for AMM testing
/// Uses simple token store system with u64 precision
module poseidon_swap::shell_token {
    use std::signer;
    use poseidon_swap::errors;

    friend poseidon_swap::pool;

    /// Shell token store for managing user balances
    struct ShellTokenStore has key {
        balance: u64,
        frozen: bool,
    }

    /// Shell token metadata
    struct ShellMetadata has key {
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
    }

    // Constants
    const SHELL_DECIMALS: u8 = 6;  // Shell uses 6 decimals
    const SHELL_NAME: vector<u8> = b"Shell";
    const SHELL_SYMBOL: vector<u8> = b"SHELL";

    /// Initialize Shell token metadata (called once)
    fun init_module(admin: &signer) {
        move_to(admin, ShellMetadata {
            name: SHELL_NAME,
            symbol: SHELL_SYMBOL,
            decimals: SHELL_DECIMALS,
            total_supply: 0,
        });
    }

    /// Ensure user has a Shell token store
    public fun ensure_token_store(user: &signer) {
        let user_addr = signer::address_of(user);
        if (!exists<ShellTokenStore>(user_addr)) {
            move_to(user, ShellTokenStore {
                balance: 0,
                frozen: false,
            });
        }
    }

    /// Get Shell balance for an address
    public fun balance_of(user_addr: address): u64 acquires ShellTokenStore {
        if (!exists<ShellTokenStore>(user_addr)) {
            return 0
        };
        let store = borrow_global<ShellTokenStore>(user_addr);
        store.balance
    }

    /// Deposit Shell to user's store
    public(friend) fun deposit(user: &signer, amount: u64) acquires ShellTokenStore {
        let user_addr = signer::address_of(user);
        ensure_token_store(user);
        
        let store = borrow_global_mut<ShellTokenStore>(user_addr);
        assert!(!store.frozen, errors::account_frozen());
        
        store.balance = store.balance + amount;
    }

    /// Withdraw Shell from user's store
    public(friend) fun withdraw(user: &signer, amount: u64) acquires ShellTokenStore {
        let user_addr = signer::address_of(user);
        assert!(exists<ShellTokenStore>(user_addr), errors::insufficient_balance());
        
        let store = borrow_global_mut<ShellTokenStore>(user_addr);
        assert!(!store.frozen, errors::account_frozen());
        assert!(store.balance >= amount, errors::insufficient_balance());
        
        store.balance = store.balance - amount;
    }

    /// Mint Shell tokens (for testing purposes)
    public fun mint_for_testing(user: &signer, amount: u64) acquires ShellTokenStore, ShellMetadata {
        ensure_token_store(user);
        
        // Update total supply
        let metadata = borrow_global_mut<ShellMetadata>(@poseidon_swap);
        metadata.total_supply = metadata.total_supply + amount;
        
        // Mint to user
        deposit(user, amount);
    }

    /// Transfer Shell between users
    public fun transfer(from: &signer, to_addr: address, amount: u64) acquires ShellTokenStore {
        // Withdraw from sender
        withdraw(from, amount);
        
        // Ensure recipient has store
        if (!exists<ShellTokenStore>(to_addr)) {
            assert!(false, errors::account_not_found());
        };
        
        // Deposit to recipient
        let to_store = borrow_global_mut<ShellTokenStore>(to_addr);
        assert!(!to_store.frozen, errors::account_frozen());
        to_store.balance = to_store.balance + amount;
    }

    /// Get total supply
    public fun total_supply(): u64 acquires ShellMetadata {
        let metadata = borrow_global<ShellMetadata>(@poseidon_swap);
        metadata.total_supply
    }

    /// Check if account is frozen
    public fun is_frozen(user_addr: address): bool acquires ShellTokenStore {
        if (!exists<ShellTokenStore>(user_addr)) {
            return false
        };
        let store = borrow_global<ShellTokenStore>(user_addr);
        store.frozen
    }

    /// Freeze/unfreeze account (admin function)
    public fun set_frozen(admin: &signer, user_addr: address, frozen: bool) acquires ShellTokenStore {
        let _admin_addr = signer::address_of(admin);
        
        if (exists<ShellTokenStore>(user_addr)) {
            let store = borrow_global_mut<ShellTokenStore>(user_addr);
            store.frozen = frozen;
        }
    }

    #[view]
    /// Get Shell metadata
    public fun get_metadata(): (vector<u8>, vector<u8>, u8) acquires ShellMetadata {
        let metadata = borrow_global<ShellMetadata>(@poseidon_swap);
        (metadata.name, metadata.symbol, metadata.decimals)
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }
} 