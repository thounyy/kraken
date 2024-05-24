#[test_only]
module kraken::test_utils {
    use std::string::{Self, String};

    use sui::coin::Coin;
    use sui::test_utils::destroy;
    use sui::transfer::Receiving;
    use sui::clock::{Self, Clock};
    use sui::test_scenario::{Self as ts, Scenario};
    
    use kraken::config;
    use kraken::account;
    use kraken::move_call;
    use kraken::coin_operations;
    use kraken::payments::{Self, Stream, Pay};
    use kraken::multisig::{Self, Multisig, Action}; 

    const OWNER: address = @0xBABE;

    // hot potato holding the state
    public struct World {
        scenario: Scenario,
        clock: Clock,
        multisig: Multisig,
    }

    public struct Obj has key, store { id: UID }

    // === Utils ===

    public fun start_world(): World {
        let mut scenario = ts::begin(OWNER);
        // initialize multisig and clock
        let multisig = multisig::new(string::utf8(b"kraken"), scenario.ctx());
        let clock = clock::create_for_testing(scenario.ctx());

        World { scenario, clock, multisig }
    }

    public fun multisig(world: &mut World): &mut Multisig {
        &mut world.multisig
    }

    public fun clock(world: &mut World): &mut Clock {
        &mut world.clock
    }

    public fun scenario(world: &mut World): &mut Scenario {
        &mut world.scenario
    }

    public fun create_proposal<T: store>(
        world: &mut World, 
        action: T,
        key: String, 
        execution_time: u64, // timestamp in ms
        expiration_epoch: u64,
        description: String
    ) {
        world.multisig.create_proposal(action, key, execution_time, expiration_epoch, description, world.scenario.ctx());
    }

    public fun clean_proposals(world: &mut World) {
        world.multisig.clean_proposals(world.scenario.ctx());
    }

    public fun delete_proposal(
        world: &mut World, 
        key: String
    ) {
        world.multisig.delete_proposal(key, world.scenario.ctx());
    }

    public fun approve_proposal(
        world: &mut World, 
        key: String, 
    ) {
        world.multisig.approve_proposal(key, world.scenario.ctx());
    }

    public fun remove_approval(
        world: &mut World, 
        key: String, 
    ) {
        world.multisig.remove_approval(key, world.scenario.ctx());
    }

    public fun execute_proposal<T: store>(
        world: &mut World, 
        key: String, 
    ): Action<T> {
        world.multisig.execute_proposal<T>(key, &world.clock, world.scenario.ctx())
    }

    public fun propose_modify(
        world: &mut World, 
        key: String,
        execution_time: u64,
        expiration_epoch: u64,
        description: String,
        name: Option<String>,
        threshold: Option<u64>, 
        to_add: vector<address>, 
        to_remove: vector<address>, 
    ) {
        config::propose_modify(
            &mut world.multisig, 
            key, 
            execution_time, 
            expiration_epoch, 
            description, 
            name, 
            threshold, 
            to_add, 
            to_remove, 
            world.scenario.ctx()
        );
    }

    public fun execute_modify(
        world: &mut World,
        name: String, 
    ) {
        config::execute_modify(&mut world.multisig, name, &world.clock, world.scenario.ctx());
    }

    public fun merge_coins<T: drop>(
        world: &mut World, 
        to_keep: Receiving<Coin<T>>,
        to_merge: vector<Receiving<Coin<T>>>, 
    ) {
        coin_operations::merge_coins(&mut world.multisig, to_keep, to_merge, world.scenario.ctx());
    }

    public fun split_coins<T: drop>(
        world: &mut World,  
        to_split: Receiving<Coin<T>>,
        amounts: vector<u64>, 
    ): vector<ID> {
        coin_operations::split_coins(&mut world.multisig, to_split, amounts, world.scenario.ctx())
    }

    public fun send_invite(world: &mut World, recipient: address) {
        account::send_invite(&mut world.multisig, recipient, world.scenario.ctx());
    }

    public fun propose_move_call(
        world: &mut World, 
        key: String,
        execution_time: u64,
        expiration_epoch: u64,
        description: String,
        digest: vector<u8>,
        to_borrow: vector<ID>,
        to_withdraw: vector<ID>,
    ) {
        move_call::propose_move_call(&mut world.multisig, key, execution_time, expiration_epoch, description, digest, to_borrow, to_withdraw, world.scenario.ctx());
    }

    public fun propose_pay(
        world: &mut World,  
        key: String,
        execution_time: u64,
        expiration_epoch: u64,
        description: String,
        coin: ID, // must have the total amount to be paid
        amount: u64, // amount to be paid at each interval
        interval: u64, // number of epochs between each payment
        recipient: address
    ) {
        payments::propose_pay(
            &mut world.multisig,
            key,
            execution_time,
            expiration_epoch,
            description,
            coin,
            amount,
            interval,
            recipient,
            world.scenario.ctx()
        );
    }

    public fun create_stream<C: drop>(
        world: &mut World, 
        action: Action<Pay>, 
        received: Receiving<Coin<C>>,
    ) {
        payments::create_stream(action, &mut world.multisig, received, world.scenario.ctx());
    }

    public fun cancel_payment<C: drop>(
        world: &mut World,
        stream: Stream<C>
    ) {
        stream.cancel_payment(&mut world.multisig, world.scenario.ctx());
    }

    public fun end(world: World) {
        let World { scenario, clock, multisig } = world;
        destroy(clock);
        destroy(multisig);
        scenario.end();
    }
}