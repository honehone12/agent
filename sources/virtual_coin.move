// This module defines a minimal and generic Coin and Balance.
// modified from https://github.com/move-language/move/tree/main/language/documentation/tutorial
//  and https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/aptos_coin.move

#[test_only]
module agent::virtual_coin {
    use std::string;
    use std::error;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability};

    const ENO_CAPABILITIES: u64 = 1;

    struct VirtualCoin has key {}

    struct CapStore has key {
        mint_cap: MintCapability<VirtualCoin>,
        burn_cap: BurnCapability<VirtualCoin>
    }

    public fun initialize(publisher: &signer): BurnCapability<VirtualCoin> {
        let (
            burn_cap, 
            freeze_cap, 
            mint_cap
        ) = coin::initialize<VirtualCoin>(
            publisher,
            string::utf8(b"Virtual Coin"),
            string::utf8(b"V"),
            0, /* decimals */
            true, /* monitor_supply */
        );

        move_to(
            publisher, 
            CapStore{ 
                mint_cap, 
                burn_cap 
            }
        );

        coin::destroy_freeze_cap(freeze_cap);
        burn_cap
    }

    public fun has_mint_capability(account: &signer): bool {
        exists<CapStore>(signer::address_of(account))
    }

    /// Create new coins and deposit them into dst_addr's account.
    public entry fun mint(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires CapStore {
        let account_addr = signer::address_of(account);

        assert!(
            exists<CapStore>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let mint_cap = &borrow_global<CapStore>(account_addr).mint_cap;
        let coins_minted = coin::mint<VirtualCoin>(amount, mint_cap);
        coin::deposit<VirtualCoin>(dst_addr, coins_minted);
    }
}
