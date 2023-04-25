module agent::coin_store {
    use aptos_framework::coin::{Self, Coin};
    use agent::agent::{Self, AgentGroup, SignerRef, Agent};

    #[resource_group_member(group = AgentGroup)]
    struct CoinStore<phantom TCoin> has key {
        coin: Coin<TCoin>
    }

    #[resource_group_member(group = AgentGroup)]
    struct Bin<phantom TCoin> has key {
        coin: Coin<TCoin>
    }

    public fun register<TCoin>(ref: &SignerRef) {
        let agent_signer = agent::generate_signer(ref);
        let agent_addr = agent::signer_address(ref);
        if (!exists<CoinStore<TCoin>>(agent_addr)) {
            move_to(
                &agent_signer,
                CoinStore{
                    coin: coin::zero<TCoin>()
                }
            );
        };
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
}