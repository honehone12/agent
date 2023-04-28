#[test_only]
module agent::preview_agent {
    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use aptos_framework::object::{Self, Object};
    use aptos_token::token::{Self, TokenId};
    use agent::agent::{Self, AgentCore, AgentRef};
    use agent::coin_store;
    use agent::token_store;
    use agent::virtual_coin::{Self, VirtualCoin};

    const ADMIN_ONLY: u64 = 1;

    struct App has key {
        user_table: SmartTable<Object<AgentCore>, AgentRef>
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

    fun create_user_agent(publisher: &signer, user: address): Object<AgentCore>
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0xcafe, ADMIN_ONLY);
        let (
            agent_signer, agent_ref
        )  = agent::create_agent(publisher, user);
        let app = borrow_global_mut<App>(pub_addr);
        let obj = object::address_to_object<AgentCore>(signer::address_of(&agent_signer));
        coin_store::register<VirtualCoin>(&agent_signer, 100);
        token_store::initialize_token_store(&agent_signer, 1);
        smart_table::add(&mut app.user_table, obj, agent_ref);
        obj
    }

    fun fund_user_agent_100(publisher: &signer, object: &Object<AgentCore>) {
        assert!(signer::address_of(publisher) == @0xcafe, ADMIN_ONLY);
        coin_store::fund<VirtualCoin>(publisher, object, 100);
    }

    fun mint_nft_for_agent_consume_100(publisher: &signer, object: &Object<AgentCore>): TokenId 
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0xcafe, ADMIN_ONLY);
        let token_id = token::create_collection_and_token(
            publisher, 1, 10000, 1,
            vector[], vector[], vector[],
            vector[false, false, false],
            vector[false, false, false, false, false],
        );
        let app = borrow_global<App>(pub_addr);
        let agent_ref = smart_table::borrow(&app.user_table, *object);
        token_store::fund(publisher, object, &token_id, 1);
        coin_store::consume<VirtualCoin>(agent_ref, 100);
        token_id
    }

    fun set_up_test(publisher: &signer, user: &signer) {
        aptos_account::create_account(signer::address_of(publisher));
        aptos_account::create_account(signer::address_of(user));
    }

    #[test(publisher = @0xcafe, user = @0x007)]
    fun test_main(publisher: &signer, user: &signer)
    acquires App {
        set_up_test(publisher, user);
        init_module(publisher);

        let agent = create_user_agent(publisher, @0x007);
        fund_user_agent_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 100, 0);
        let id = mint_nft_for_agent_consume_100(publisher, &agent);
        assert!(coin_store::balance<VirtualCoin>(&agent) == 0, 1);
        assert!(token_store::balance(&agent, &id) == 1, 2);
    }
}
