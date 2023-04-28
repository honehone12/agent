module agent::agent {
    use std::error;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::object::{Self, Object, ExtendRef, TransferRef};

    const E_ACCOUNT_NOT_INITIALIZED: u64 = 1;

    #[resource_group(scope = global)]
    struct AgentGroup {}

    #[resource_group_member(group = AgentGroup)]
    struct AgentCore has key {
        owner: address,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef
    }

    struct AgentRef has store {
        inner: address
    }

    struct RevokedRef has drop {
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

    public fun revoke(agent: AgentRef): RevokedRef {
        let AgentRef{inner: addr} = agent;
        RevokedRef{inner: addr}
    }

    public fun revoked_address(ref: &RevokedRef): address {
        ref.inner
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
