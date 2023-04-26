module use_cases::preview_agent {
    use std::signer;
    use std::option;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::coin;
    use agent::agent::{Self, Agent, SignerRef};
    use agent::coin_store;
    use agent::token_store;
    use use_cases::virtual_coin::{Self, VirtualCoin};

    const ADMIN_ONLY: u64 = 1;

    struct App has key {
        user_table: SmartTable<Agent, SignerRef>
    }

    fun init_module(publisher: &signer) {
        virtual_coin::initialize(publisher);
        coin::register<VirtualCoin>(publisher);
        virtual_coin::mint(publisher, signer::address_of(publisher), 100_000_000_000);

        move_to(
            publisher,
            App{
                user_table: smart_table::new()
            }
        );
    }

    fun create_user_agent(publisher: &signer, username: vector<u8>): Agent
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, ADMIN_ONLY);
        let constructor = agent::create_agent(publisher, username);
        let agent = agent::agent_from_constructor_ref(&constructor);
        let signer_ref = agent::generate_signer_ref(&constructor);
        let app = borrow_global_mut<App>(pub_addr);
        coin_store::register<VirtualCoin>(&signer_ref, option::none());
        token_store::initialize_token_store(&signer_ref);
        smart_table::add(&mut app.user_table, agent, signer_ref);
        agent
    }

    fun fund_user_agent_100(publisher: &signer, agent: &Agent) {
        assert!(signer::address_of(publisher) == @0x007, ADMIN_ONLY);
        coin_store::fund<VirtualCoin>(publisher, agent, 100);
    }

    #[test_only]
    use aptos_token::token::{Self, TokenId};

    #[test_only]
    fun mint_nft_for_agent_consume_100(publisher: &signer, agent: &Agent): TokenId 
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, ADMIN_ONLY);
        let token_id = token::create_collection_and_token(
            publisher, 1, 10000, 1,
            vector[], vector[], vector[],
            vector[false, false, false],
            vector[false, false, false, false, false],
        );
        let token = token::withdraw_token(publisher, token_id, 1);
        let app = borrow_global<App>(pub_addr);
        let signer_ref = smart_table::borrow(&app.user_table, *agent);
        token_store::fund(signer_ref, token);
        coin_store::consume<VirtualCoin>(signer_ref, 100);
        token_id
    }

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    fun set_up_test(publisher: &signer) {
        account::create_account_for_test(signer::address_of(publisher));
    }

    #[test(publisher = @0x007)]
    fun test_main(publisher: &signer)
    acquires App {
        set_up_test(publisher);
        init_module(publisher);

        let agent = create_user_agent(publisher, b"myname");
        fund_user_agent_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 100, 0);
        let id = mint_nft_for_agent_consume_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 0, 1);
        assert!(token_store::balance(&agent, &id) == 1, 2);
    }
}
