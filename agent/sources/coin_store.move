module agent::coin_store {
    use std::error;
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use agent::agent::{Self, AgentGroup, SignerRef, Agent};

    const E_TIME_LOCK_NOT_INITILIZED: u64 = 1;
    const E_OWNER_NOT_INITIALIZED: u64 = 2;

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
        assert!(
            exists<TimeLock<TCoin>>(agent_addr), 
            error::not_found(E_TIME_LOCK_NOT_INITILIZED)
        );    
        assert!(
            agent::has_on_chain_owner(&agent::address_to_agent(agent_addr)),
            error::permission_denied(E_OWNER_NOT_INITIALIZED)
        );
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

    public fun num_locked<TCoin>(agent: &Agent): u64
    acquires TimeLock {
        let agent_addr = agent::agent_address(agent);
        if (exists<TimeLock<TCoin>>(agent_addr)) {
            let time_lock = borrow_global<TimeLock<TCoin>>(agent_addr);
            vector::length(&time_lock.locks)
        } else {
            0
        }
    }

    public fun oldest_expiration_seconds<TCoin>(agent: &Agent): Option<u64>
    acquires TimeLock {
        let agent_addr = agent::agent_address(agent);
        if (exists<TimeLock<TCoin>>(agent_addr)) {
            let time_lock = borrow_global<TimeLock<TCoin>>(agent_addr);
            if  (vector::length(&time_lock.locks) > 0) {
                let lock = vector::borrow(&time_lock.locks, 0);
                return option::some(lock.expiration)
            }
        };
        option::none()
    }

    public fun unlock_oldest<TCoin>(ref: &SignerRef): Option<Coin<TCoin>>
    acquires TimeLock {
        let signer_addr = agent::signer_address(ref);
        assert!(
            exists<TimeLock<TCoin>>(signer_addr), 
            error::not_found(E_TIME_LOCK_NOT_INITILIZED)
        );
        let time_lock = borrow_global_mut<TimeLock<TCoin>>(signer_addr);
        if (vector::length(&time_lock.locks) > 0) {
            let expiration = vector::borrow(&time_lock.locks, 0).expiration;
            let now = timestamp::now_seconds();
            if (now > expiration) {
                let lock = vector::remove(&mut time_lock.locks, 0);
                let Lock{
                    coin,
                    expiration: _
                } = lock;
                return option::some(coin)
            };
        };
        option::none() 
    }

    public fun drain() {
        
    }
}