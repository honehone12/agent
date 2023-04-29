module agent::agent {
    use std::signer;
    use std::error;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ObjectGroup, ExtendRef, TransferRef};

    const E_ACCOUNT_NOT_INITIALIZED: u64 = 1;
    const E_NOT_OWNER: u64 = 2;

    #[resource_group_member(group = ObjectGroup)]
    struct AgentCore has key {
        owner: address,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef
    }

    struct AgentRef has store {
        inner: address
    }

    public fun is_agent(location: address): bool {
        exists<AgentCore>(location)
    }

    public fun agent_owner(object: &Object<AgentCore>): address
    acquires AgentCore {
        let core = borrow_global<AgentCore>(object::object_address(object));
        core.owner
    }

    public fun agent_owner_from_ref(ref: &AgentRef): address
    acquires AgentCore {
        let core = borrow_global<AgentCore>(ref.inner);
        core.owner
    }

    public fun agent_address(agent: &AgentRef): address {
        agent.inner
    }

    public fun revoke(agent: AgentRef)
    acquires AgentCore {
        let AgentRef{inner: addr} = agent;
        let core = borrow_global<AgentCore>(addr);
        let linear = object::generate_linear_transfer_ref(&core.transfer_ref);
        object::transfer_with_ref(linear, core.owner);        
    }

    public fun generate_signer_with_ref(ref: &AgentRef): signer
    acquires AgentCore {
        let core = borrow_global<AgentCore>(ref.inner);
        object::generate_signer_for_extending(&core.extend_ref)
    }

    public fun generate_signer_for_owner(owner: &signer, object: &Object<AgentCore>): signer
    acquires AgentCore {
        let agent_addr = object::object_address(object);
        let core = borrow_global<AgentCore>(agent_addr);
        assert!(signer::address_of(owner) == core.owner, error::permission_denied(E_NOT_OWNER));
        object::generate_signer_for_extending(&core.extend_ref)
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
        let extend_ref = object::generate_extend_ref(&obj_constructor);
        let transfer_ref = object::generate_transfer_ref(&obj_constructor);
        object::disable_ungated_transfer(&transfer_ref);

        let agent_core = AgentCore {
            owner: user,
            extend_ref,
            transfer_ref,
        };
        move_to(&obj_signer, agent_core);

        (obj_signer, AgentRef{inner: obj_addr})
    }
}
