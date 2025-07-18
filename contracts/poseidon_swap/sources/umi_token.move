/// UMI Token Module (Compatible with UmiNetwork op-move)
/// Provides u256 UMI token operations following the official op-move patterns
/// This is a mock implementation that matches the official interface
module poseidon_swap::umi_token {
    use std::signer;
    use poseidon_swap::errors;

    friend poseidon_swap::pool;

    /// UMI token store for managing user balances (u256)
    struct UMITokenStore has key {
        balance: u256,
        frozen: bool,
    }

    /// UMI token metadata (mock implementation)
    struct UMIMetadata has key {
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u256,
    }

    /// Mock managed fungible asset structure (similar to op-move)
    struct ManagedFungibleAsset has key {
        // In real implementation, these would be the actual MintRef, etc.
        metadata_addr: address,
    }

    // Constants matching op-move UMI token
    const ASSET_SYMBOL: vector<u8> = b"UMI";
    const ASSET_NAME: vector<u8> = b"Umi";
    const UMI_DECIMALS: u8 = 18;

    /// Initialize UMI token metadata (called once)
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Create metadata
        move_to(admin, UMIMetadata {
            name: ASSET_NAME,
            symbol: ASSET_SYMBOL,
            decimals: UMI_DECIMALS,
            total_supply: 0,
        });

        // Create managed fungible asset
        move_to(admin, ManagedFungibleAsset {
            metadata_addr: admin_addr,
        });
    }

    /// Get UMI metadata object (similar to op-move get_metadata())
    public fun get_metadata(): address {
        @poseidon_swap
    }

    /// Get UMI balance for an address (matches op-move get_balance)
    public fun get_balance(account: address): u256 acquires UMITokenStore {
        if (!exists<UMITokenStore>(account)) {
            return 0
        };
        let store = borrow_global<UMITokenStore>(account);
        store.balance
    }

    /// Ensure user has a UMI token store
    public fun ensure_token_store(user: &signer) {
        let user_addr = signer::address_of(user);
        if (!exists<UMITokenStore>(user_addr)) {
            move_to(user, UMITokenStore {
                balance: 0,
                frozen: false,
            });
        }
    }

    /// Get UMI balance for an address (convenience function for pool)
    public fun balance_of(user_addr: address): u256 acquires UMITokenStore {
        get_balance(user_addr)
    }

    /// Mint UMI tokens (matches op-move mint function signature)
    public entry fun mint(admin: &signer, to: address, amount: u256) acquires UMITokenStore, UMIMetadata {
        // Verify admin permissions (in real implementation)
        let _admin_addr = signer::address_of(admin);
        
        // Ensure store exists
        if (!exists<UMITokenStore>(to)) {
            move_to(admin, UMITokenStore {
                balance: 0,
                frozen: false,
            });
        };
        
        // Update total supply
        let metadata = borrow_global_mut<UMIMetadata>(@poseidon_swap);
        metadata.total_supply = metadata.total_supply + amount;
        
        // Mint to user
        let store = borrow_global_mut<UMITokenStore>(to);
        assert!(!store.frozen, errors::account_frozen());
        store.balance = store.balance + amount;
    }

    /// Transfer UMI tokens (matches op-move transfer function signature)
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u256) acquires UMITokenStore {
        // In real implementation, admin can transfer on behalf of users
        let _admin_addr = signer::address_of(admin);
        
        // Verify from account has sufficient balance
        assert!(exists<UMITokenStore>(from), errors::insufficient_balance());
        let from_store = borrow_global_mut<UMITokenStore>(from);
        assert!(!from_store.frozen, errors::account_frozen());
        assert!(from_store.balance >= amount, errors::insufficient_balance());
        
        // Ensure to account has store
        if (!exists<UMITokenStore>(to)) {
            // Cannot create store for another user in this context
            assert!(false, errors::account_not_found());
        };
        
        // Perform transfer
        from_store.balance = from_store.balance - amount;
        
        let to_store = borrow_global_mut<UMITokenStore>(to);
        assert!(!to_store.frozen, errors::account_frozen());
        to_store.balance = to_store.balance + amount;
    }

    /// Burn UMI tokens (matches op-move burn function signature)
    public entry fun burn(admin: &signer, from: address, amount: u256) acquires UMITokenStore, UMIMetadata {
        let _admin_addr = signer::address_of(admin);
        
        // Verify account has sufficient balance
        assert!(exists<UMITokenStore>(from), errors::insufficient_balance());
        let store = borrow_global_mut<UMITokenStore>(from);
        assert!(!store.frozen, errors::account_frozen());
        assert!(store.balance >= amount, errors::insufficient_balance());
        
        // Burn tokens
        store.balance = store.balance - amount;
        
        // Update total supply
        let metadata = borrow_global_mut<UMIMetadata>(@poseidon_swap);
        metadata.total_supply = metadata.total_supply - amount;
    }

    /// Deposit UMI to user's store (for pool operations)
    public(friend) fun deposit(user: &signer, amount: u256) acquires UMITokenStore {
        let user_addr = signer::address_of(user);
        ensure_token_store(user);
        
        let store = borrow_global_mut<UMITokenStore>(user_addr);
        assert!(!store.frozen, errors::account_frozen());
        
        store.balance = store.balance + amount;
    }

    /// Withdraw UMI from user's store (for pool operations)
    public(friend) fun withdraw(user: &signer, amount: u256) acquires UMITokenStore {
        let _user_addr = signer::address_of(user);
        assert!(exists<UMITokenStore>(_user_addr), errors::insufficient_balance());
        
        let store = borrow_global_mut<UMITokenStore>(_user_addr);
        assert!(!store.frozen, errors::account_frozen());
        assert!(store.balance >= amount, errors::insufficient_balance());
        
        store.balance = store.balance - amount;
    }

    /// Mint UMI tokens for testing purposes
    public fun mint_for_testing(user: &signer, amount: u256) acquires UMITokenStore, UMIMetadata {
        let user_addr = signer::address_of(user);
        ensure_token_store(user);
        
        // Update total supply
        let metadata = borrow_global_mut<UMIMetadata>(@poseidon_swap);
        metadata.total_supply = metadata.total_supply + amount;
        
        // Mint to user
        deposit(user, amount);
    }

    /// Transfer UMI between users (public interface)
    public fun transfer_between_users(from: &signer, to_addr: address, amount: u256) acquires UMITokenStore {
        // Withdraw from sender
        withdraw(from, amount);
        
        // Ensure recipient has store
        if (!exists<UMITokenStore>(to_addr)) {
            assert!(false, errors::account_not_found());
        };
        
        // Deposit to recipient
        let to_store = borrow_global_mut<UMITokenStore>(to_addr);
        assert!(!to_store.frozen, errors::account_frozen());
        to_store.balance = to_store.balance + amount;
    }

    /// Convert u256 UMI amount to u64 for pool calculations (scale down)
    public fun to_pool_amount(umi_amount: u256): u64 {
        // Scale down by 10^10 to fit in u64
        let scaled = umi_amount / 10000000000;
        assert!(scaled <= (18446744073709551615 as u256), errors::amount_too_large());
        (scaled as u64)
    }

    /// Convert u64 pool amount back to u256 UMI amount (scale up)
    public fun from_pool_amount(pool_amount: u64): u256 {
        (pool_amount as u256) * 10000000000
    }

    /// Get total supply
    public fun total_supply(): u256 acquires UMIMetadata {
        let metadata = borrow_global<UMIMetadata>(@poseidon_swap);
        metadata.total_supply
    }

    /// Check if account is frozen
    public fun is_frozen(user_addr: address): bool acquires UMITokenStore {
        if (!exists<UMITokenStore>(user_addr)) {
            return false
        };
        let store = borrow_global<UMITokenStore>(user_addr);
        store.frozen
    }

    /// Freeze/unfreeze account (admin function)
    public fun set_frozen(admin: &signer, user_addr: address, frozen: bool) acquires UMITokenStore {
        // In real implementation, would check admin permissions
        let _admin_addr = signer::address_of(admin);
        
        if (exists<UMITokenStore>(user_addr)) {
            let store = borrow_global_mut<UMITokenStore>(user_addr);
            store.frozen = frozen;
        }
    }

    #[view]
    /// Get UMI metadata
    public fun get_metadata_info(): (vector<u8>, vector<u8>, u8) acquires UMIMetadata {
        let metadata = borrow_global<UMIMetadata>(@poseidon_swap);
        (metadata.name, metadata.symbol, metadata.decimals)
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }
} 