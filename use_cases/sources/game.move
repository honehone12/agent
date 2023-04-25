module use_cases::game {
    use std::signer;
    use std::option;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::coin;
    use aptos_token::token;
    use agent::agent::{Self, Agent, SignerRef};
    use agent::coin_store;
    use use_cases::virtual_coin::{Self, VirtualCoin};

    const ADMIN_ONLY: u64 = 1;

    struct Game has key {
        user_table: SmartTable<Agent, SignerRef>
    }

    fun init_module(publisher: &signer) {
        virtual_coin::initialize(publisher);
        coin::register<VirtualCoin>(publisher);
        virtual_coin::mint(publisher, signer::address_of(publisher), 100_000_000_000);

        move_to(
            publisher,
            Game{
                user_table: smart_table::new()
            }
        );
    }

    fun create_user_agent(publisher: &signer, username: vector<u8>): Agent
    acquires Game {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, ADMIN_ONLY);
        let constructor = agent::create_agent(publisher, username);
        let agent = agent::agent_from_constructor_ref(&constructor);
        let signer_ref = agent::generate_signer_ref(&constructor);
        let agent_signer = agent::generate_signer(&signer_ref);
        let game = borrow_global_mut<Game>(pub_addr);
        coin_store::register<VirtualCoin>(&signer_ref, option::none());
        token::initialize_token_store(&agent_signer);
        smart_table::add(&mut game.user_table, agent, signer_ref);
        agent
    }

    fun fund_user_agent_100(publisher: &signer, agent: &Agent) {
        assert!(signer::address_of(publisher) == @0x007, ADMIN_ONLY);
        coin_store::fund<VirtualCoin>(publisher, agent, 100);
    }

    #[test_only]
    fun mint_nft_for_agent_consume_100(publisher: &signer, agent: &Agent)
    acquires Game {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, ADMIN_ONLY);
        let token_id = token::create_collection_and_token(
            publisher, 1, 10000, 1,
            vector[], vector[], vector[],
            vector[false, false, false],
            vector[false, false, false, false, false],
        );
        let game = borrow_global<Game>(pub_addr);
        let signer_ref = smart_table::borrow(&game.user_table, *agent);
        let agent_signer = agent::generate_signer(signer_ref);
        token::direct_transfer(publisher, &agent_signer, token_id, 1);
        coin_store::consume<VirtualCoin>(signer_ref, 100);
    }

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    fun set_up_test(publisher: &signer) {
        account::create_account_for_test(signer::address_of(publisher));
    }

    #[test(publisher = @0x007)]
    fun test_main(publisher: &signer)
    acquires Game {
        set_up_test(publisher);
        init_module(publisher);

        let agent = create_user_agent(publisher, b"myname");
        fund_user_agent_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 100, 0);
        mint_nft_for_agent_consume_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 0, 1);
    }
}
