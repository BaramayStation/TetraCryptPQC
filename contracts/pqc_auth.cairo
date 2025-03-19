#[contract]
mod TetraCryptAuth {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use starknet::contract_address::ContractAddressZeroable;
    use array::ArrayTrait;
    use box::BoxTrait;
    use option::OptionTrait;
    use traits::Into;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        KeyRegistered: KeyRegistered,
        KeyValidated: KeyValidated,
        KeyRevoked: KeyRevoked,
    }

    #[derive(Drop, starknet::Event)]
    struct KeyRegistered {
        #[key]
        user: ContractAddress,
        key_hash: felt252,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct KeyValidated {
        #[key]
        user: ContractAddress,
        validator: ContractAddress,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct KeyRevoked {
        #[key]
        user: ContractAddress,
        timestamp: u64
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct QuantumKeyData {
        key_hash: felt252,
        timestamp: u64,
        is_valid: bool,
        validator: ContractAddress
    }

    #[storage]
    struct Storage {
        quantum_keys: LegacyMap<ContractAddress, QuantumKeyData>,
        owner: ContractAddress,
        paused: bool
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.paused.write(false);
    }

    #[external(v0)]
    fn register_quantum_key(ref self: ContractState, key_hash: felt252) {
        // Ensure contract is not paused
        assert(!self.paused.read(), 'Contract is paused');
        
        // Get caller address
        let caller = get_caller_address();
        
        // Ensure key doesn't exist
        let existing_key = self.quantum_keys.read(caller);
        assert(existing_key.key_hash.is_zero(), 'Key already registered');
        
        // Create new key data
        let timestamp = starknet::get_block_timestamp();
        let key_data = QuantumKeyData {
            key_hash: key_hash,
            timestamp: timestamp,
            is_valid: false,
            validator: ContractAddressZeroable::zero()
        };
        
        // Store key data
        self.quantum_keys.write(caller, key_data);
        
        // Emit event
        self.emit(Event::KeyRegistered(KeyRegistered { 
            user: caller, 
            key_hash: key_hash,
            timestamp: timestamp
        }));
    }

    #[external(v0)]
    fn validate_quantum_key(ref self: ContractState, user: ContractAddress) {
        // Ensure contract is not paused
        assert(!self.paused.read(), 'Contract is paused');
        
        // Get caller address
        let validator = get_caller_address();
        
        // Get key data
        let mut key_data = self.quantum_keys.read(user);
        
        // Validate key
        assert(!key_data.key_hash.is_zero(), 'Key not registered');
        assert(!key_data.is_valid, 'Key already validated');
        
        // Update key data
        key_data.is_valid = true;
        key_data.validator = validator;
        self.quantum_keys.write(user, key_data);
        
        // Emit event
        self.emit(Event::KeyValidated(KeyValidated { 
            user: user,
            validator: validator,
            timestamp: starknet::get_block_timestamp()
        }));
    }

    #[external(v0)]
    fn revoke_quantum_key(ref self: ContractState) {
        // Get caller address
        let caller = get_caller_address();
        
        // Ensure key exists
        let key_data = self.quantum_keys.read(caller);
        assert(!key_data.key_hash.is_zero(), 'No key registered');
        
        // Remove key
        self.quantum_keys.write(
            caller,
            QuantumKeyData {
                key_hash: 0,
                timestamp: 0,
                is_valid: false,
                validator: ContractAddressZeroable::zero()
            }
        );
        
        // Emit event
        self.emit(Event::KeyRevoked(KeyRevoked { 
            user: caller,
            timestamp: starknet::get_block_timestamp()
        }));
    }

    #[view]
    fn is_key_valid(self: @ContractState, user: ContractAddress) -> bool {
        let key_data = self.quantum_keys.read(user);
        key_data.is_valid
    }

    #[external(v0)]
    fn pause(ref self: ContractState) {
        // Only owner can pause
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'Not authorized');
        self.paused.write(true);
    }

    #[external(v0)]
    fn unpause(ref self: ContractState) {
        // Only owner can unpause
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'Not authorized');
        self.paused.write(false);
    }
} 