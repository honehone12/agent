#[test_only]
module agent::test_agent {
    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::account;
    use aptos_framework::coin;
    use agent::agent::{Self, Agent, SignerRef};
    use agent::v_aptos_coin::{Self, VAptosCoin};

    struct App has key {
        agent_table: SmartTable<Agent, SignerRef>
    }

    fun set_up_coin(publisher: &signer) {
        account::create_account_for_test(signer::address_of(publisher));
        coin::register<VAptosCoin>(publisher);
        let (burn_cap, mint_cap) = v_aptos_coin::initialize(publisher);
        v_aptos_coin::mint(publisher, signer::address_of(publisher), 1000_000_000_000);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    fun set_up_app(publisher: &signer) {
        let app = App {
            agent_table: smart_table::new()
        };
        move_to(publisher, app);
    }

    fun create_app_agent(publisher: &signer, seed: vector<u8>): Agent
    acquires App {
        let agent_constructor = agent::create_agent(publisher, seed);
        let agent_signer_ref = agent::generate_signer_ref(&agent_constructor);
        let agent = agent::agent_from_constructor_ref(&agent_constructor);
        let app = borrow_global_mut<App>(signer::address_of(publisher));
        agent::register_coin<VAptosCoin>(&agent_signer_ref);
        smart_table::add(&mut app.agent_table, agent, agent_signer_ref);
        agent
    }

    #[test(publisher = @0xcafe)]
    fun test_coin(publisher: &signer)
    acquires App {
        {
            set_up_coin(publisher);
            set_up_app(publisher);
        };
        let agent = create_app_agent(publisher, b"username1");
        {
            agent::fund_coin<VAptosCoin>(publisher, agent, 1000_000);        
            assert!(agent::coin_balance<VAptosCoin>(agent) == 1000_000, 0);
        };
    }

    #[test(publisher = @0xcafe)]
    fun test_create_and_register(publisher: &signer) {
        let constructor = agent::create_agent(publisher, b"username");
        let signer_ref = agent::generate_signer_ref(&constructor);
        agent::register_apt(&signer_ref);
        agent::register_token(&signer_ref);
    }

    #[test(publisher = @0xcafe)]
    #[expected_failure]
    fun test_fail_create_twice(publisher: &signer) {
        agent::create_agent(publisher, b"username");
        agent::create_agent(publisher, b"username");
    }
}