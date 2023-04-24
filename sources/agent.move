module agent::agent {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;
    use aptos_token::token;
    use aptos_framework::aptos_coin::AptosCoin;

    const E_AGENT_EXISTS: u64 = 1;
    const E_AGENT_NOT_EXISTS: u64 = 2;
    const E_NONCE_OVERFLOW: u64 = 3;
    const E_INVALID_NONCE: u64 = 4;

    #[resource_group(scope = global)]
    struct AgentGroup {}

    #[resource_group_member(group = AgentGroup)]
    struct AgentCore has key {
        signer_capability: SignerCapability,
        owner: Option<address>
    }

    struct Agent has store, copy, drop {
        inner: address
    }

    struct ConstructorRef has drop {
        inner: address
    }

    struct SignerRef has store, drop {
        inner: address
    }

    public fun agent_address(agent: &Agent): address {
        agent.inner
    }

    public fun address_to_agent(agent_address: address): Agent {
        assert!(exists<AgentCore>(agent_address), error::not_found(E_AGENT_NOT_EXISTS));
        Agent{inner: agent_address}
    }

    public fun agent_from_constructor_ref(constructor: &ConstructorRef): Agent {
        Agent{inner: constructor.inner}
    }

    public fun generate_signer_ref(constructor: &ConstructorRef): SignerRef {
        SignerRef{inner: constructor.inner}
    }

    public fun generate_signer(ref: &SignerRef): signer
    acquires AgentCore {
        let core = borrow_global_mut<AgentCore>(ref.inner);
        account::create_signer_with_capability(&core.signer_capability)
    }

    public fun signer_address(ref: &SignerRef): address {
        ref.inner
    }

    public fun register_coin<TCoin>(ref: &SignerRef)
    acquires AgentCore {
        let agent_signer = generate_signer(ref);
        coin::register<TCoin>(&agent_signer); 
    }

    public fun register_apt(ref: &SignerRef)
    acquires AgentCore {
        register_coin<AptosCoin>(ref);
    }

    public fun register_token(ref: &SignerRef)
    acquires AgentCore {
        let agent_signer = generate_signer(ref);
        token::initialize_token_store(&agent_signer);
    }
    
    public fun create_agent(publisher: &signer, seed: vector<u8>): ConstructorRef {
        let (
            resource_signer, 
            signer_cap
        ) = account::create_resource_account(publisher, seed);
        let resource_addr = signer::address_of(&resource_signer);
        assert!(!exists<AgentCore>(resource_addr), error::already_exists(E_AGENT_EXISTS));

        let agent_core = AgentCore {
            signer_capability: signer_cap,
            owner: option::none()
        };
        move_to(&resource_signer, agent_core);
        ConstructorRef{inner: resource_addr}
    }

    public fun set_owner(ref: &SignerRef, owner: address)
    acquires AgentCore {
        let core = borrow_global_mut<AgentCore>(signer_address(ref));
        option::fill(&mut core.owner, owner);
    }

    public fun fund_coin<TCoin>(funder: &signer, agent: Agent, amount: u64) {
        coin::transfer<TCoin>(funder, agent.inner, amount);
    }

    public fun coin_balance<TCoin>(agent: Agent): u64 {
        coin::balance<TCoin>(agent.inner)
    }
}