module use_cases::game {
    use std::signer;
    use aptos_framework::coin;
    use use_cases::virtual_coin::{Self, VirtualCoin};

    fun init_module(publisher: &signer) {
        let (
            burn_cap,
            mint_cap
        ) = virtual_coin::initialize(publisher);
        coin::destroy_mint_cap<VirtualCoin>(mint_cap);
        coin::destroy_burn_cap<VirtualCoin>(burn_cap);
        coin::register<VirtualCoin>(publisher);
        virtual_coin::mint(publisher, signer::address_of(publisher), 100_000_000_000);
    }

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    fun set_up_test(publisher: &signer) {
        account::create_account_for_test(signer::address_of(publisher));
    }

    #[test(publisher = @0x007)]
    fun test_main(publisher: &signer) {
        set_up_test(publisher);
        init_module(publisher);
    }
}