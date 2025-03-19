// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title TetraCryptPQC Smart Contract
 * @dev Implements secure post-quantum key exchange validation on blockchain
 */
contract TetraCryptPQC is ReentrancyGuard, Ownable, Pausable {
    // Struct to store quantum key data
    struct QuantumKeyData {
        bytes32 publicKeyHash;
        uint256 timestamp;
        bool isValid;
        address validator;
    }
    
    // Mapping of addresses to their quantum key data
    mapping(address => QuantumKeyData) public quantumKeys;
    
    // Events for key operations
    event KeyRegistered(address indexed user, bytes32 keyHash);
    event KeyValidated(address indexed user, address indexed validator);
    event KeyRevoked(address indexed user);
    
    // Security parameters
    uint256 public constant KEY_EXPIRATION_TIME = 24 hours;
    uint256 public constant MIN_VALIDATION_STAKE = 1 ether;
    
    constructor() {
        _pause(); // Start paused for security
    }
    
    /**
     * @dev Register a new quantum key hash
     * @param keyHash Hash of the quantum public key
     */
    function registerQuantumKey(bytes32 keyHash) external payable nonReentrant whenNotPaused {
        require(msg.value >= MIN_VALIDATION_STAKE, "Insufficient stake");
        require(quantumKeys[msg.sender].publicKeyHash == bytes32(0), "Key already registered");
        
        quantumKeys[msg.sender] = QuantumKeyData({
            publicKeyHash: keyHash,
            timestamp: block.timestamp,
            isValid: false,
            validator: address(0)
        });
        
        emit KeyRegistered(msg.sender, keyHash);
    }
    
    /**
     * @dev Validate a registered quantum key
     * @param user Address of the key owner
     */
    function validateQuantumKey(address user) external nonReentrant whenNotPaused {
        require(quantumKeys[user].publicKeyHash != bytes32(0), "Key not registered");
        require(!quantumKeys[user].isValid, "Key already validated");
        require(block.timestamp - quantumKeys[user].timestamp <= KEY_EXPIRATION_TIME, "Key expired");
        
        quantumKeys[user].isValid = true;
        quantumKeys[user].validator = msg.sender;
        
        emit KeyValidated(user, msg.sender);
    }
    
    /**
     * @dev Revoke a quantum key
     */
    function revokeQuantumKey() external nonReentrant {
        require(quantumKeys[msg.sender].publicKeyHash != bytes32(0), "No key registered");
        
        delete quantumKeys[msg.sender];
        
        emit KeyRevoked(msg.sender);
    }
    
    /**
     * @dev Verify if a quantum key is valid
     * @param user Address to check
     * @return bool indicating if the key is valid
     */
    function isQuantumKeyValid(address user) external view returns (bool) {
        return quantumKeys[user].isValid &&
               block.timestamp - quantumKeys[user].timestamp <= KEY_EXPIRATION_TIME;
    }
    
    /**
     * @dev Emergency pause for security
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Resume operations
     */
    function resume() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Withdraw stuck funds (only owner)
     */
    function withdrawStuckFunds() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
} 