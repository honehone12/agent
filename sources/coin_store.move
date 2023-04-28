module agent::coin_store {
    use std::signer;
    use std::error;
    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::object::{Self, Object};
    use agent::agent::{Self, AgentRef, AgentCore, AgentGroup, RevokedRef};

    const E_NOT_AGENT: u64 = 1;
    const E_OVER_CONSUME: u64 = 2;
    const E_NOT_OWNER: u64 = 3;

    #[resource_group_member(group = AgentGroup)]
    struct CoinStore<phantom TCoin> has key {
        max_consumable: u64,
        coin: Coin<TCoin>
    }

    #[resource_group_member(group = AgentGroup)]
    struct Bin<phantom TCoin> has key {
        coin: Coin<TCoin>
    }

    public fun register<TCoin>(agent_signer: &signer, max_consumable: u64) {
        assert!(
            agent::is_agent(signer::address_of(agent_signer)), 
            error::permission_denied(E_NOT_AGENT)
        );
        move_to(
            agent_signer,
            CoinStore<TCoin>{
                max_consumable,
                coin: coin::zero()
            }
        );
        move_to(
            agent_signer,
            Bin<TCoin>{
                coin: coin::zero()
            }
        );
    }

    public fun balance<TCoin>(object: &Object<AgentCore>): u64
    acquires CoinStore {
        let agent_addr = object::object_address(object);
        if (exists<CoinStore<TCoin>>(agent_addr)) {
            let store = borrow_global<CoinStore<TCoin>>(agent_addr);
            coin::value<TCoin>(&store.coin)
        } else {
            0
        }
    }

    public fun fund<TCoin>(funder: &signer, object: &Object<AgentCore>, amount: u64)
    acquires CoinStore {
        let store = borrow_global_mut<CoinStore<TCoin>>(object::object_address(object));
        let coin = coin::withdraw<TCoin>(funder, amount);
        coin::merge<TCoin>(&mut store.coin, coin);
    }

    public fun transfer_to_owner<TCoin>(ref: &AgentRef)
    acquires CoinStore {
        let agent_addr = agent::agent_address(ref);
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        let coin = coin::extract_all(&mut store.coin);
        let owner = agent::agent_owner_from_ref(ref);
        aptos_account::deposit_coins(owner, coin);
    }

    public fun transfer_by_owner<TCoin>(owner: &signer, object: &Object<AgentCore>)
    acquires CoinStore {
        let owner_addr = agent::agent_owner(object);
        assert!(signer::address_of(owner) == owner_addr, error::permission_denied(E_NOT_OWNER));
        let store = borrow_global_mut<CoinStore<TCoin>>(object::object_address(object));
        let coin = coin::extract_all(&mut store.coin);
        aptos_account::deposit_coins(owner_addr, coin);
    }

    public fun consume<TCoin>(ref: &AgentRef, amount: u64)
    acquires CoinStore, Bin {
        let agent_addr = agent::agent_address(ref);
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        assert!(amount <= store.max_consumable, error::permission_denied(E_OVER_CONSUME));
        let consume_coin = coin::extract(&mut store.coin, amount);
        let bin = borrow_global_mut<Bin<TCoin>>(agent_addr);
        coin::merge<TCoin>(&mut bin.coin, consume_coin);        
    }

    public fun withdraw_from_bin<TCoin>(ref: &RevokedRef): Coin<TCoin>
    acquires Bin {
        let revoked_addr = agent::revoked_address(ref);
        let bin = borrow_global_mut<Bin<TCoin>>(revoked_addr);
        coin::extract_all(&mut bin.coin)
    }    
}
