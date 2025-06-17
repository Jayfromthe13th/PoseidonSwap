/// LP Token management for PoseidonSwap AMM
/// Handles liquidity provider token creation, minting, and burning using Fungible Asset standard
module poseidon_swap::lp_token {
    use std::option;
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use poseidon_swap::errors;

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

        object::object_from_constructor_ref(constructor_ref)
    }

    /// Mint LP tokens to a user
    public fun mint_lp_tokens(
        metadata: Object<Metadata>,
        to: address,
        amount: u64,
    ) acquires LPTokenRefs {
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        let fa = fungible_asset::mint(&lp_token_refs.mint_ref, amount);
        primary_fungible_store::deposit(to, fa);
    }

    /// Burn LP tokens from a user
    public fun burn_lp_tokens(
        metadata: Object<Metadata>,
        from: &signer,
        amount: u64,
    ) acquires LPTokenRefs {
        let lp_token_refs = borrow_global<LPTokenRefs>(object::object_address(&metadata));
        let fa = primary_fungible_store::withdraw(from, metadata, amount);
        fungible_asset::burn(&lp_token_refs.burn_ref, fa);
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

    /// Get LP token total supply
    #[view]
    public fun total_supply(metadata: Object<Metadata>): option::Option<u128> {
        fungible_asset::supply(metadata)
    }

    /// Get LP token balance for an account
    #[view]
    public fun balance(account: address, metadata: Object<Metadata>): u64 {
        primary_fungible_store::balance(account, metadata)
    }

    /// Check if account has primary store for LP token
    public fun ensure_primary_store_exists(account: address, metadata: Object<Metadata>) {
        if (!primary_fungible_store::primary_store_exists(account, metadata)) {
            primary_fungible_store::create_primary_store(account, metadata);
        };
    }

    /// Get the current supply as u64 (for compatibility)
    #[view]
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

    /// Get LP token metadata information
    #[view]
    public fun get_metadata_info(metadata: Object<Metadata>): (String, String, u8) {
        (
            fungible_asset::name(metadata),
            fungible_asset::symbol(metadata),
            fungible_asset::decimals(metadata)
        )
    }

    /// Check if LP token is frozen for an account
    #[view]
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

    /// Get the metadata object address
    #[view]
    public fun get_metadata_address(metadata: Object<Metadata>): address {
        object::object_address(&metadata)
    }

    /// Check if LP token refs exist (for validation)
    #[view]
    public fun lp_token_refs_exist(metadata: Object<Metadata>): bool {
        exists<LPTokenRefs>(object::object_address(&metadata))
    }
} 