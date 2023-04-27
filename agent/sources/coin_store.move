module agent::coin_store {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::object::{Self, Object};
    use agent::agent::{Self, AgentRef, AgentCore};

    const E_OWNER_NOT_INITIALIZED: u64 = 1;
    const E_NOT_OWNER: u64 = 2;
    const E_NOT_AGENT: u64 = 3;

    #[resource_group_member(group = AgentGroup)]
    struct CoinStore<phantom TCoin> has key {
        coin: Coin<TCoin>
    }

    #[resource_group_member(group = AgentGroup)]
    struct Bin<phantom TCoin> has key {
        coin: Coin<TCoin>
    }

    #[resource_group_member(group = AgentGroup)]
    struct TimeLock<phantom TCoin> has key {
        time_lock_seconds: u64,
        lock: Option<Lock<TCoin>>
    }

    struct Lock<phantom TCoin> has store {
        coin: Coin<TCoin>,
        expiration: u64
    }

    public fun register<TCoin>(agent_signer: &signer, time_lock_seconds: u64) {
        assert!(
            agent::is_agent(signer::address_of(agent_signer)), 
            error::permission_denied(E_NOT_AGENT)
        );
        move_to(
            agent_signer,
            CoinStore<TCoin>{
                coin: coin::zero()
            }
        );
        move_to(
            agent_signer,
            Bin<TCoin>{
                coin: coin::zero()
            }
        );
        move_to(
            agent_signer,
            TimeLock<TCoin>{
                lock: option::none(),
                time_lock_seconds
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

    public fun consume<TCoin>(ref: &AgentRef, amount: u64)
    acquires CoinStore, Bin {
        let agent_addr = agent::agent_address(ref);
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        let consume_coin = coin::extract<TCoin>(&mut store.coin, amount);
        let bin = borrow_global_mut<Bin<TCoin>>(agent_addr);
        coin::merge<TCoin>(&mut bin.coin, consume_coin);        
    }

    public fun reserve<TCoin>(owner: &signer, object: &Object<AgentCore>)
    acquires CoinStore, TimeLock {
        let agent_owner = agent::agent_owner(object);
        assert!(
            option::is_some(&agent_owner),
            error::permission_denied(E_OWNER_NOT_INITIALIZED)
        );
        assert!(
            option::destroy_some(agent_owner) == signer::address_of(owner),
            error::permission_denied(E_NOT_OWNER)
        );       
        
        let agent_addr = object::object_address(object);    
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        let reserve_coin = coin::extract_all<TCoin>(&mut store.coin);
        let now = timestamp::now_seconds();       
        let time_lock = borrow_global_mut<TimeLock<TCoin>>(agent_addr);
        let lock = Lock<TCoin>{
            coin: reserve_coin,
            expiration: now + time_lock.time_lock_seconds
        };
        option::fill(&mut time_lock.lock, lock);
    }
}