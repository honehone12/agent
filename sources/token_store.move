module agent::token_store {
    use std::error;
    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_token::token::{Self, TokenId, Token};
    use aptos_framework::object::{Self, Object};
    use agent::agent::{Self, AgentRef, AgentCore, AgentGroup};

    const E_ZERO_TOKEN: u64 = 1;
    const E_NOT_AGENT: u64 = 2;

    #[resource_group_member(group = AgentGroup)]
    struct TokenStore has key {
        max_consumable: u64,
        tokens: SmartTable<TokenId, Token>
    }

    #[resource_group_member(group = AgentGroup)]
    struct Bin has key {
        tokens: SmartTable<TokenId, Token>
    }

    public fun initialize_token_store(agent_signer: &signer, max_consumable: u64) {
        assert!(
            agent::is_agent(signer::address_of(agent_signer)), 
            error::permission_denied(E_NOT_AGENT)
        );

        move_to(
            agent_signer,
            TokenStore{
                max_consumable,
                tokens: smart_table::new()
            }
        );
        move_to(
            agent_signer,
            Bin{
                tokens: smart_table::new()
            }
        );
    }

    public fun fund(funder: &signer, object: &Object<AgentCore>, id: &TokenId, amount: u64)
    acquires TokenStore {
        let token = token::withdraw_token(funder, *id, amount);
        let store = borrow_global_mut<TokenStore>(object::object_address(object));
        if (!smart_table::contains(&store.tokens,  *id)) {
            assert!(token::get_token_amount(&token) > 0, error::invalid_argument(E_ZERO_TOKEN));
            smart_table::add(&mut store.tokens, *id, token);
        } else {
            let stored = smart_table::borrow_mut(&mut store.tokens, *id);
            token::merge(stored, token);
        };
    }

    public fun balance(object: &Object<AgentCore>, id: &TokenId): u64
    acquires TokenStore {
        let agent_addr = object::object_address(object);
        if (exists<TokenStore>(agent_addr)) {
            let store = borrow_global<TokenStore>(agent_addr);
            if (smart_table::contains(&store.tokens, *id)) {
                let stored = smart_table::borrow(&store.tokens, *id);
                return token::get_token_amount(stored)
            }
        };
        0 
    }

    public fun consume(ref: &AgentRef, id: &TokenId, amount: u64)
    acquires TokenStore, Bin {
        let agent_addr = agent::agent_address(ref);
        let store = borrow_global_mut<TokenStore>(agent_addr);
        let stored = smart_table::borrow_mut(&mut store.tokens, *id);
        let consumed = token::split(stored, amount);
        let bin = borrow_global_mut<Bin>(agent_addr);

        if (!smart_table::contains(&bin.tokens,  *id)) {
            smart_table::add(&mut store.tokens, *id, consumed);
        } else {
            let stored = smart_table::borrow_mut(&mut bin.tokens, *id);
            token::merge(stored, consumed);
        };
    }   
}