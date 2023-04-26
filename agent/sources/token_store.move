module agent::token_store {
    use std::error;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_token::token::{Self, TokenId, Token};
    use agent::agent::{Self, SignerRef, Agent};

    const E_ZERO_TOKEN: u64 = 1;

    struct TokenStore has key {
        tokens: SmartTable<TokenId, Token>
    }

    struct Bin has key {
        tokens: SmartTable<TokenId, Token>
    }

    public fun initialize_token_store(ref: &SignerRef) {
        let agent_addr = agent::signer_address(ref);
        let agent_signer = agent::generate_signer(ref);
        if (!exists<TokenStore>(agent_addr)) {
            move_to(
                &agent_signer,
                TokenStore{
                    tokens: smart_table::new()
                }
            );
        };
        if (!exists<Bin>(agent_addr)) {
            move_to(
                &agent_signer,
                Bin{
                    tokens: smart_table::new()
                }
            );
        };
    }

    public fun fund(ref: &SignerRef, token: Token)
    acquires TokenStore {
        let store = borrow_global_mut<TokenStore>(agent::signer_address(ref));
        let token_id = token::token_id(&token);
        if (!smart_table::contains(&store.tokens,  *token_id)) {
            assert!(token::get_token_amount(&token) > 0, error::invalid_argument(E_ZERO_TOKEN));
            smart_table::add(&mut store.tokens, *token_id, token);
        } else {
            let stored = smart_table::borrow_mut(&mut store.tokens, *token_id);
            token::merge(stored, token);
        };
    }

    public fun balance(agent: &Agent, id: &TokenId): u64
    acquires TokenStore {
        let agent_addr = agent::agent_address(agent);
        if (exists<TokenStore>(agent_addr)) {
            let store = borrow_global<TokenStore>(agent_addr);
            if (smart_table::contains(&store.tokens, *id)) {
                let stored = smart_table::borrow(&store.tokens, *id);
                return token::get_token_amount(stored)
            }
        };
        0 
    }

    public fun consume(agent: &Agent, id: &TokenId, amount: u64)
    acquires TokenStore, Bin {
        let agent_addr = agent::agent_address(agent);
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