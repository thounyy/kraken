/// This module allows to manage a Multisig's settings.
/// The action can be to add or remove members, and to change the threshold.

module kraken::config {
    use std::string::String;
    
    use sui::clock::Clock;
    use kraken::multisig::Multisig;

    // === Errors ===

    const EThresholdTooHigh: u64 = 0;
    const ENotMember: u64 = 1;
    const EAlreadyMember: u64 = 2;
    const EThresholdNull: u64 = 3;

    // === Structs ===

    public struct Witness has drop {}

    // [ACTION]
    public struct Modify has store { 
        // new name if any
        name: Option<String>,
        // new threshold, has to be <= to new total addresses
        threshold: Option<u64>,
        // addresses to add
        to_add: vector<address>,
        // weights of the members that will be added
        weights: vector<u64>,
        // addresses to remove
        to_remove: vector<address>,
    }

    // === Multisig-only functions ===

    // step 1: propose to modify multisig params
    public fun propose_modify(
        multisig: &mut Multisig, 
        key: String,
        execution_time: u64,
        expiration_epoch: u64,
        description: String,
        name: Option<String>,
        threshold: Option<u64>, 
        to_add: vector<address>, 
        weights: vector<u64>,
        to_remove: vector<address>, 
        ctx: &mut TxContext
    ) {
        // verify proposed addresses match current list
        let mut i = 0;
        while (i < to_add.length()) {
            assert!(!multisig.is_member(to_add[i]), EAlreadyMember);
            i = i + 1;
        };
        let mut j = 0;
        while (j < to_remove.length()) {
            assert!(multisig.is_member(to_remove[j]), ENotMember);
            j = j + 1;
        };

        let new_threshold = if (threshold.is_some()) {
            // if threshold null, anyone can propose
            assert!(*threshold.borrow() > 0, EThresholdNull);
            *threshold.borrow()
        } else {
            multisig.threshold()
        };
        // verify threshold is reachable with new members 
        let new_len = multisig.member_addresses().length() + to_add.length() - to_remove.length();
        assert!(new_len >= new_threshold, EThresholdTooHigh);

        let proposal_mut = multisig.create_proposal(
            Witness {},
            key,
            execution_time,
            expiration_epoch,
            description,
            ctx
        );
        proposal_mut.push_action(Modify { name, threshold, to_add, weights, to_remove });
    }

    // step 2: multiple members have to approve the proposal (multisig::approve_proposal)
    
    // step 3: execute the action and modify Multisig object
    public fun execute_modify(
        multisig: &mut Multisig, 
        name: String, 
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let mut executable = multisig.execute_proposal(name, clock, ctx);
        let Modify { mut name, mut threshold, to_add, weights, to_remove } = executable.pop_action(Witness {});
        executable.destroy_executable(Witness {});

        if (name.is_some()) multisig.set_name(name.extract());
        if (threshold.is_some()) multisig.set_threshold(threshold.extract());
        multisig.add_members(to_add, weights);
        multisig.remove_members(to_remove);
    }
}

