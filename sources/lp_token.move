/// LP Token management for PoseidonSwap AMM
/// Handles liquidity provider token creation, minting, and burning using Fungible Asset standard
module poseidon_swap::lp_token {
    use std::option;
    use std::string::{Self, String};
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use poseidon_swap::errors;

    friend poseidon_swap::pool;

    /// Initialize the LP token module (called once)
    fun init_module(_admin: &signer) {
        // Module is initialized but no global state needed
        // LP token metadata is created per-pool
    }

    /// LP Token metadata and references
    struct LPTokenRefs has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }



    /// Initialize LP token for a pool
    /// Creates a new fungible asset for LP tokens with proper metadata
    public fun initialize_lp_token(
        creator: &signer,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
    ): Object<Metadata> {
        let constructor_ref = &object::create_named_object(creator, *string::bytes(&name));
        
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            LPTokenRefs {
                mint_ref,
                transfer_ref, 
                burn_ref,
            }
        );

        let metadata = object::object_from_constructor_ref(constructor_ref);
        
        metadata
    }

    /// Mint LP tokens to a user (convenience function)
    public(friend) fun mint_to(user: &signer, metadata: Object<Metadata>, amount: u64) acquires LPTokenRefs {
        let user_addr = std::signer::address_of(user);
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        let fa = fungible_asset::mint(&lp_token_refs.mint_ref, amount);
        primary_fungible_store::deposit(user_addr, fa);
    }

    /// Burn LP tokens from a user (convenience function)
    public(friend) fun burn_from(user: &signer, metadata: Object<Metadata>, amount: u64) acquires LPTokenRefs {
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        let fa = primary_fungible_store::withdraw(user, metadata, amount);
        fungible_asset::burn(&lp_token_refs.burn_ref, fa);
    }

    /// Get LP token balance for a user (convenience function)
    public fun balance_of(user_addr: address, metadata: Object<Metadata>): u64 {
        primary_fungible_store::balance(user_addr, metadata)
    }



    /// Transfer LP tokens between users
    public fun transfer_lp_tokens(
        from: &signer,
        to: address,
        metadata: Object<Metadata>,
        amount: u64,
    ) {
        let fa = primary_fungible_store::withdraw(from, metadata, amount);
        primary_fungible_store::deposit(to, fa);
    }

    #[view]
    /// Get LP token total supply
    public fun total_supply(metadata: Object<Metadata>): option::Option<u128> {
        fungible_asset::supply(metadata)
    }

    #[view]
    /// Get LP token balance for an account
    public fun balance(account: address, metadata: Object<Metadata>): u64 {
        primary_fungible_store::balance(account, metadata)
    }

    /// Check if account has primary store for LP token
    public fun ensure_primary_store_exists(account: address, metadata: Object<Metadata>) {
        if (!primary_fungible_store::primary_store_exists(account, metadata)) {
            primary_fungible_store::create_primary_store(account, metadata);
        };
    }

    #[view]
    /// Get the current supply as u64 (for compatibility)
    public fun get_supply(metadata: Object<Metadata>): u64 {
        let supply_option = fungible_asset::supply(metadata);
        if (option::is_some(&supply_option)) {
            let supply_u128 = option::extract(&mut supply_option);
            assert!(supply_u128 <= (18446744073709551615 as u128), errors::overflow());
            (supply_u128 as u64)
        } else {
            0
        }
    }

    #[view]
    /// Get LP token metadata information
    public fun get_metadata_info(metadata: Object<Metadata>): (String, String, u8) {
        (
            fungible_asset::name(metadata),
            fungible_asset::symbol(metadata),
            fungible_asset::decimals(metadata)
        )
    }

    #[view]
    /// Check if LP token is frozen for an account
    public fun is_frozen(account: address, metadata: Object<Metadata>): bool {
        primary_fungible_store::is_frozen(account, metadata)
    }

    /// Freeze LP tokens for an account (admin function)
    public fun freeze_account(metadata: Object<Metadata>, account: address) acquires LPTokenRefs {
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        primary_fungible_store::set_frozen_flag(&lp_token_refs.transfer_ref, account, true);
    }

    /// Unfreeze LP tokens for an account (admin function)
    public fun unfreeze_account(metadata: Object<Metadata>, account: address) acquires LPTokenRefs {
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        primary_fungible_store::set_frozen_flag(&lp_token_refs.transfer_ref, account, false);
    }

    /// Withdraw LP tokens as FungibleAsset (for advanced operations)
    public fun withdraw_lp_tokens(
        from: &signer,
        metadata: Object<Metadata>,
        amount: u64,
    ): FungibleAsset {
        primary_fungible_store::withdraw(from, metadata, amount)
    }

    /// Deposit LP tokens from FungibleAsset (for advanced operations)
    public fun deposit_lp_tokens(to: address, fa: FungibleAsset) {
        primary_fungible_store::deposit(to, fa);
    }

    #[view]
    /// Get the metadata object address
    public fun get_metadata_address(metadata: Object<Metadata>): address {
        object::object_address(&metadata)
    }

    #[view]
    /// Check if LP token refs exist (for validation)
    public fun lp_token_refs_exist(metadata: Object<Metadata>): bool {
        exists<LPTokenRefs>(object::object_address(&metadata))
    }

    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(admin: &signer) {
        init_module(admin);
    }
} 