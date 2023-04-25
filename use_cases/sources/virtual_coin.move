// This module defines a minimal and generic Coin and Balance.
// modified from https://github.com/move-language/move/tree/main/language/documentation/tutorial
//  and https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/aptos_coin.move

module use_cases::virtual_coin {
    use std::string;
    use std::error;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability};

    /// Account does not have mint capability
    const ENO_CAPABILITIES: u64 = 1;

    struct VirtualCoin has key {}

    struct MintCapStore has key {
        mint_cap: MintCapability<VirtualCoin>,
    }

    public fun initialize(publisher: &signer)
    : (BurnCapability<VirtualCoin>, MintCapability<VirtualCoin>) {

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<VirtualCoin>(
            publisher,
            string::utf8(b"Virtual Coin"),
            string::utf8(b"V"),
            0, /* decimals */
            true, /* monitor_supply */
        );

        // Aptos framework needs mint cap to mint coins to initial validators. This will be revoked once the validators
        // have been initialized.
        move_to(publisher, MintCapStore { mint_cap });

        coin::destroy_freeze_cap(freeze_cap);
        (burn_cap, mint_cap)
    }

    public fun has_mint_capability(account: &signer): bool {
        exists<MintCapStore>(signer::address_of(account))
    }

    /// Create new coins and deposit them into dst_addr's account.
    public entry fun mint(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires MintCapStore {
        let account_addr = signer::address_of(account);

        assert!(
            exists<MintCapStore>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let mint_cap = &borrow_global<MintCapStore>(account_addr).mint_cap;
        let coins_minted = coin::mint<VirtualCoin>(amount, mint_cap);
        coin::deposit<VirtualCoin>(dst_addr, coins_minted);
    }
}
