module agent::agent {
    use std::error;
    use std::option::{Self, Option};
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object};

    const E_ACCOUNT_NOT_INITIALIZED: u64 = 1;

    #[resource_group(scope = global)]
    struct AgentGroup {}

    #[resource_group_member(group = AgentGroup)]
    struct AgentCore has key {
        owner: Option<address>
    }

    struct AgentRef has store {
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
    
    public fun set_owner(ref: AgentRef, owner: address)
    acquires AgentCore {
        let core = borrow_global_mut<AgentCore>(agent_address(&ref));
        option::fill(&mut core.owner, owner);
        let AgentRef{inner:_} = ref;
    }

    public fun create_agent(publisher: &signer, user: address): (signer, AgentRef) {
        assert!(
            account::exists_at(user) && coin::is_account_registered<AptosCoin>(user),
            error::invalid_argument(E_ACCOUNT_NOT_INITIALIZED)
        );
        
        let seed = string_utils::to_string_with_canonical_addresses(&user);
        let obj_constructor = object::create_named_object(publisher, *string::bytes(&seed));
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
}
