module agent::coin_store {
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use agent::agent::{Self, AgentGroup, SignerRef, Agent};

    const E_TIME_LOCK_NOT_INITILIZED: u64 = 1;

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
        lock_seconds: u64,
        locks: vector<Lock<TCoin>>
    }

    struct Lock<phantom TCoin> has store {
        coin: Coin<TCoin>,
        expiration: u64
    }

    public fun register<TCoin>(ref: &SignerRef, time_lock_seconds: Option<u64>) {
        let agent_signer = agent::generate_signer(ref);
        let agent_addr = agent::signer_address(ref);
        if (!exists<CoinStore<TCoin>>(agent_addr)) {
            move_to(
                &agent_signer,
                CoinStore<TCoin>{
                    coin: coin::zero()
                }
            );
        };
        if (!exists<Bin<TCoin>>(agent_addr)) {
            move_to(
                &agent_signer,
                Bin<TCoin>{
                    coin: coin::zero()
                }
            );
        };
        if (option::is_some(&time_lock_seconds) && !exists<TimeLock<TCoin>>(agent_addr)) {
            move_to(
                &agent_signer,
                TimeLock<TCoin>{
                    locks: vector::empty(),
                    lock_seconds: option::extract(&mut time_lock_seconds)
                }
            );
        }
    }

    public fun balance<TCoin>(agent: &Agent): u64
    acquires CoinStore {
        let agent_addr = agent::agent_address(agent);
        if (exists<CoinStore<TCoin>>(agent_addr)) {
            let store = borrow_global<CoinStore<TCoin>>(agent_addr);
            coin::value<TCoin>(&store.coin)
        } else {
            0
        }
    }

    public fun fund<TCoin>(funder: &signer, agent: &Agent, amount: u64)
    acquires CoinStore {
        let store = borrow_global_mut<CoinStore<TCoin>>(agent::agent_address(agent));
        let coin = coin::withdraw<TCoin>(funder, amount);
        coin::merge<TCoin>(&mut store.coin, coin);
    }

    public fun consume<TCoin>(ref: &SignerRef, amount: u64)
    acquires CoinStore, Bin {
        let agent_addr = agent::signer_address(ref);
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        let consume_coin = coin::extract<TCoin>(&mut store.coin, amount);
        let bin = borrow_global_mut<Bin<TCoin>>(agent_addr);
        coin::merge<TCoin>(&mut bin.coin, consume_coin);        
    }

    public fun reserve<TCoin>(ref: &SignerRef, amount: u64)
    acquires CoinStore, TimeLock {
        let agent_addr = agent::signer_address(ref);
        let store = borrow_global_mut<CoinStore<TCoin>>(agent_addr);
        let reserve_coin = coin::extract<TCoin>(&mut store.coin, amount);
        let now = timestamp::now_seconds();       
        let time_lock = borrow_global_mut<TimeLock<TCoin>>(agent_addr);
        let lock = Lock<TCoin>{
            coin: reserve_coin,
            expiration: now + time_lock.lock_seconds
        };
        vector::push_back(&mut time_lock.locks, lock);
    }
}