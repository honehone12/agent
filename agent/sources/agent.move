module agent::agent {
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object};

    #[resource_group(scope = global)]
    struct AgentGroup {}

    #[resource_group_member(group = AgentGroup)]
    struct AgentCore has key {
        owner: Option<address>
    }

    struct AgentRef has store, drop {
        inner: address
    }

    public fun is_agent(location: address): bool {
        exists<AgentCore>(location)
    }

    public fun agent_publisher(object: &Object<AgentCore>): address {
        object::owner(*object)
    }

    public fun agent_owner(object: &Object<AgentCore>): Option<address>
    acquires AgentCore {
        let core = borrow_global<AgentCore>(object::object_address(object));
        core.owner
    }

    public fun agent_address(agent: &AgentRef): address {
        agent.inner
    }
    
    public fun set_owner(ref: &AgentRef, owner: address)
    acquires AgentCore {
        let core = borrow_global_mut<AgentCore>(agent_address(ref));
        option::fill(&mut core.owner, owner);
    }

    public fun create_agent(publisher: &signer, seed: vector<u8>): (signer, AgentRef) {
        let obj_constructor = object::create_named_object(publisher, seed);
        let obj_addr = object::address_from_constructor_ref(&obj_constructor);
        let obj_signer = object::generate_signer(&obj_constructor);
        let transfer_ref = object::generate_transfer_ref(&obj_constructor);
        object::disable_ungated_transfer(&transfer_ref);

        let agent_core = AgentCore {
            owner: option::none()
        };
        move_to(&obj_signer, agent_core);

        (obj_signer, AgentRef{inner: obj_addr})
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
