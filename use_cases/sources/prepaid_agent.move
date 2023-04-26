module use_cases::prepaid_agent {
    use std::signer;
    use std::option;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use agent::agent::{Self, Agent, SignerRef};
    use agent::coin_store;

    const E_ADMIN_ONLY: u64 = 1;
    const E_UNLOCK_FAIL: u64 = 2;

    const TIME_LOCK_SECONDS: u64 = 604800; // a week

    struct App has key {
        user_table: SmartTable<Agent, SignerRef>
    }

    fun init_module(publisher: &signer) {
        move_to(
            publisher,
            App{
                user_table: smart_table::new()
            }
        )
    }

    fun create_user_agent(publisher: &signer, owner: address, username: vector<u8>): Agent
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, E_ADMIN_ONLY);
        let constructor = agent::create_agent(publisher, username);
        let agent = agent::agent_from_constructor_ref(&constructor);
        let signer_ref = agent::generate_signer_ref(&constructor);
        let app = borrow_global_mut<App>(pub_addr);
        agent::set_owner(&signer_ref, owner);
        coin_store::register<AptosCoin>(&signer_ref, option::some(TIME_LOCK_SECONDS));
        smart_table::add(&mut app.user_table, agent, signer_ref);
        agent
    }

    fun pay_one_apt(publisher: &signer, agent: &Agent)
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, E_ADMIN_ONLY);
        let app = borrow_global<App>(pub_addr);
        let signer_ref = smart_table::borrow(&app.user_table, *agent);
        coin_store::reserve<AptosCoin>(signer_ref, 100_000_000);
    }

    fun try_unlock_oldest(publisher: &signer, agent: &Agent)
    acquires App {
        let pub_addr = signer::address_of(publisher);
        assert!(pub_addr == @0x007, E_ADMIN_ONLY);
        let app = borrow_global<App>(pub_addr);
        let signer_ref = smart_table::borrow(&app.user_table, *agent);
        let option = coin_store::unlock_oldest<AptosCoin>(signer_ref);
        if (option::is_some(&option)) {
            let coin = option::destroy_some(option);
            coin::deposit(pub_addr, coin);
        } else {
            abort(E_UNLOCK_FAIL)
        };
    }

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    fun set_up_test(publisher: &signer, user: &signer, framework: &signer) {
        let pub_addr = signer::address_of(publisher);
        let user_addr = signer::address_of(user);
        account::create_account_for_test(pub_addr);
        account::create_account_for_test(user_addr);
        account::create_account_for_test(signer::address_of(framework));
        coin::register<AptosCoin>(publisher);
        coin::register<AptosCoin>(user);
        let (
            burn_cap,
            mint_cap
        ) = aptos_coin::initialize_for_test(framework);
        aptos_coin::mint(framework, pub_addr, 10_000_000_000);
        aptos_coin::mint(framework, user_addr, 1000_000_000);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
        timestamp::set_time_has_started_for_testing(framework);
    }

    #[test(publisher = @0x007, user = @0x008, framework = @0x1)]
    fun test_main(publisher: &signer, user: &signer, framework: &signer)
    acquires App {
        set_up_test(publisher, user, framework);
        init_module(publisher);

        let agent = create_user_agent(publisher, signer::address_of(user), b"username");

        coin_store::fund<AptosCoin>(user, &agent, 100_000_000);
        assert!(coin_store::balance<AptosCoin>(&agent) == 100_000_000, 0);
        assert!(coin::balance<AptosCoin>(signer::address_of(user)) == 900_000_000, 1);

        pay_one_apt(publisher, &agent);
        assert!(coin_store::num_locked<AptosCoin>(&agent) == 1, 2);
        assert!(option::destroy_some(coin_store::oldest_expiration_seconds<AptosCoin>(&agent)) == TIME_LOCK_SECONDS, 3);
    
        timestamp::fast_forward_seconds(TIME_LOCK_SECONDS + 1);
        try_unlock_oldest(publisher, &agent);
        assert!(coin::balance<AptosCoin>(signer::address_of(publisher)) == 10_100_000_000, 4);
    }   
}
