module agent::agent {
    use std::signer;
    use std::error;
    use std::option::{Self, Option};
    use aptos_framework::account::{Self, SignerCapability};

    const E_AGENT_EXISTS: u64 = 1;
    const E_AGENT_NOT_EXISTS: u64 = 2;
    const E_NONCE_OVERFLOW: u64 = 3;
    const E_INVALID_NONCE: u64 = 4;

    #[resource_group(scope = global)]
    struct AgentGroup {}

    #[resource_group_member(group = AgentGroup)]
    struct AgentCore has key {
        publisher: address,
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

    public fun is_agent(location: address): bool {
        exists<AgentCore>(location)
    }

    public fun agent_publisher(agent: &Agent): address
    acquires AgentCore {
        let core = borrow_global<AgentCore>(agent.inner);
        core.publisher
    }

    public fun agnet_owner(agent: &Agent): Option<address>
    acquires AgentCore {
        let core = borrow_global<AgentCore>(agent.inner);
        core.owner
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
    
    public fun set_owner(ref: &SignerRef, owner: address)
    acquires AgentCore {
        let core = borrow_global_mut<AgentCore>(signer_address(ref));
        option::fill(&mut core.owner, owner);
    }

    public fun create_agent(publisher: &signer, seed: vector<u8>): ConstructorRef {
        let (
            resource_signer, 
            signer_cap
        ) = account::create_resource_account(publisher, seed);
        let resource_addr = signer::address_of(&resource_signer);
        assert!(!exists<AgentCore>(resource_addr), error::already_exists(E_AGENT_EXISTS));

        let agent_core = AgentCore {
            publisher: signer::address_of(publisher),
            signer_capability: signer_cap,
            owner: option::none()
        };
        move_to(&resource_signer, agent_core);

        ConstructorRef{inner: resource_addr}
    }

    #[test(publisher = @0xcafe)]
    fun test_create(publisher: &signer) {
        create_agent(publisher, b"username");
    }

    #[test(publisher = @0xcafe)]
    #[expected_failure]
    fun test_fail_create_twice(publisher: &signer) {
        create_agent(publisher, b"username");
        create_agent(publisher, b"username");
    }
}
