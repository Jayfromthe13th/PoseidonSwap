// APT Token Mock Module
/// Provides simple APT token operations for AMM testing
/// Uses simple token store system with u64 precision
module poseidon_swap::apt_token {
    use std::signer;
    use poseidon_swap::errors;

    friend poseidon_swap::pool;

    /// APT token store for managing user balances
    struct APTTokenStore has key {
        balance: u64,
        frozen: bool,
    }

    /// APT token metadata
    struct APTMetadata has key {
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
    }

    // Constants
    const APT_DECIMALS: u8 = 8;
    const APT_NAME: vector<u8> = b"Aptos Token";
    const APT_SYMBOL: vector<u8> = b"APT";

    /// Initialize APT token metadata (called once)
    fun init_module(admin: &signer) {
        move_to(admin, APTMetadata {
            name: APT_NAME,
            symbol: APT_SYMBOL,
            decimals: APT_DECIMALS,
            total_supply: 0,
        });
    }

    /// Ensure user has an APT token store
    public fun ensure_token_store(user: &signer) {
        let user_addr = signer::address_of(user);
        if (!exists<APTTokenStore>(user_addr)) {
            move_to(user, APTTokenStore {
                balance: 0,
                frozen: false,
            });
        }
    }

    /// Get APT balance for an address
    public fun balance_of(user_addr: address): u64 acquires APTTokenStore {
        if (!exists<APTTokenStore>(user_addr)) {
            return 0
        };
        let store = borrow_global<APTTokenStore>(user_addr);
        store.balance
    }

    /// Deposit APT to user's store
    public(friend) fun deposit(user: &signer, amount: u64) acquires APTTokenStore {
        let user_addr = signer::address_of(user);
        ensure_token_store(user);
        
        let store = borrow_global_mut<APTTokenStore>(user_addr);
        assert!(!store.frozen, errors::account_frozen());
        
        store.balance = store.balance + amount;
    }

    /// Withdraw APT from user's store
    public(friend) fun withdraw(user: &signer, amount: u64) acquires APTTokenStore {
        let user_addr = signer::address_of(user);
        assert!(exists<APTTokenStore>(user_addr), errors::insufficient_balance());
        
        let store = borrow_global_mut<APTTokenStore>(user_addr);
        assert!(!store.frozen, errors::account_frozen());
        assert!(store.balance >= amount, errors::insufficient_balance());
        
        store.balance = store.balance - amount;
    }

    /// Mint APT tokens (for testing purposes)
    public fun mint_for_testing(user: &signer, amount: u64) acquires APTTokenStore, APTMetadata {
        ensure_token_store(user);
        
        // Update total supply
        let metadata = borrow_global_mut<APTMetadata>(@poseidon_swap);
        metadata.total_supply = metadata.total_supply + amount;
        
        // Mint to user
        deposit(user, amount);
    }

    /// Transfer APT between users
    public fun transfer(from: &signer, to_addr: address, amount: u64) acquires APTTokenStore {
        // Withdraw from sender
        withdraw(from, amount);
        
        // Ensure recipient has store
        if (!exists<APTTokenStore>(to_addr)) {
            assert!(false, errors::account_not_found());
        };
        
        // Deposit to recipient
        let to_store = borrow_global_mut<APTTokenStore>(to_addr);
        assert!(!to_store.frozen, errors::account_frozen());
        to_store.balance = to_store.balance + amount;
    }

    /// Get total supply
    public fun total_supply(): u64 acquires APTMetadata {
        let metadata = borrow_global<APTMetadata>(@poseidon_swap);
        metadata.total_supply
    }

    /// Check if account is frozen
    public fun is_frozen(user_addr: address): bool acquires APTTokenStore {
        if (!exists<APTTokenStore>(user_addr)) {
            return false
        };
        let store = borrow_global<APTTokenStore>(user_addr);
        store.frozen
    }

    /// Freeze/unfreeze account (admin function)
    public fun set_frozen(admin: &signer, user_addr: address, frozen: bool) acquires APTTokenStore {
        let _admin_addr = signer::address_of(admin);
        
        if (exists<APTTokenStore>(user_addr)) {
            let store = borrow_global_mut<APTTokenStore>(user_addr);
            store.frozen = frozen;
        }
    }

    #[view]
    /// Get APT metadata
    public fun get_metadata(): (vector<u8>, vector<u8>, u8) acquires APTMetadata {
        let metadata = borrow_global<APTMetadata>(@poseidon_swap);
        (metadata.name, metadata.symbol, metadata.decimals)
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }
} 