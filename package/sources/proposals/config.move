/// This module allows to manage a Multisig's settings.
/// The action can be to add or remove members, and to change the threshold.

module kraken::config {
    use std::string::String;
    use kraken::multisig::{Multisig, Executable};

    // === Errors ===

    const EThresholdTooHigh: u64 = 0;
    const ENotMember: u64 = 1;
    const EAlreadyMember: u64 = 2;
    const EThresholdNull: u64 = 3;

    // === Structs ===

    public struct Witness has drop {}

    // [ACTION] upgrade is separate for better ux
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

    // [ACTION] update the version of the multisig
    public struct Migrate has store { 
        // the new version
        version: u64,
    }

    // === [PROPOSAL] Public functions ===

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
        let modify = new_modify(multisig, name, threshold, to_add, weights, to_remove);
        let proposal_mut = multisig.create_proposal(
            Witness {},
            key,
            execution_time,
            expiration_epoch,
            description,
            ctx
        );
        proposal_mut.push_action(modify);
    }

    // step 2: multiple members have to approve the proposal (multisig::approve_proposal)
    
    // step 3: execute the action and modify Multisig object
    public fun execute_modify(
        mut executable: Executable,
        multisig: &mut Multisig, 
    ) {
        let idx = executable.executable_last_action_idx();
        modify(&mut executable, multisig, Witness {}, idx);
        destroy_modify(&mut executable, Witness {});
        executable.destroy_executable(Witness {});
    }

    // step 1: propose to update the version
    public fun propose_migrate(
        multisig: &mut Multisig, 
        key: String,
        execution_time: u64,
        expiration_epoch: u64,
        description: String,
        version: u64,
        ctx: &mut TxContext
    ) {
        let proposal_mut = multisig.create_proposal(
            Witness {},
            key,
            execution_time,
            expiration_epoch,
            description,
            ctx
        );
        proposal_mut.push_action(new_migrate(version));
    }

    // step 2: multiple members have to approve the proposal (multisig::approve_proposal)

    // step 3: execute the action and modify Multisig object
    public fun execute_migrate(
        mut executable: Executable,
        multisig: &mut Multisig, 
    ) {
        let idx = executable.executable_last_action_idx();
        migrate(&mut executable, multisig, Witness {}, idx);
        destroy_migrate(&mut executable, Witness {});
        executable.destroy_executable(Witness {});
    }

    // === [ACTION] Public functions ===

    public fun new_modify(
        multisig: &Multisig,
        name: Option<String>,
        threshold: Option<u64>, 
        to_add: vector<address>, 
        weights: vector<u64>,
        to_remove: vector<address>, 
    ): Modify {
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
        
        Modify { name, threshold, to_add, weights, to_remove }
    }    
    
    public fun modify<W: drop>(
        executable: &mut Executable,
        multisig: &mut Multisig, 
        witness: W,
        idx: u64,
    ) {
        let modify_mut: &mut Modify = executable.action_mut(witness, idx);

        if (modify_mut.name.is_some()) multisig.set_name(modify_mut.name.extract());
        if (modify_mut.threshold.is_some()) multisig.set_threshold(modify_mut.threshold.extract());
        multisig.add_members(modify_mut.to_add, modify_mut.weights);
        multisig.remove_members(modify_mut.to_remove);
    }

    public fun destroy_modify<W: drop>(
        executable: &mut Executable,
        witness: W,
    ): (Option<String>, Option<u64>, vector<address>, vector<u64>, vector<address>) {
        let Modify { name, threshold, to_add, weights, to_remove } = executable.pop_action(witness);
        (name, threshold, to_add, weights, to_remove)
    }

    public fun new_migrate(version: u64): Migrate {
        Migrate { version }
    }

    public fun migrate<W: drop>(
        executable: &mut Executable,
        multisig: &mut Multisig, 
        witness: W,
        idx: u64,
    ) {
        let migrate_mut: &mut Migrate = executable.action_mut(witness, idx);
        multisig.set_version(migrate_mut.version);
    }
        
    public fun destroy_migrate<W: drop>(
        executable: &mut Executable,
        witness: W,
    ): u64 {
        let Migrate { version } = executable.pop_action(witness);
        version
    }
}

