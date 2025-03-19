import numpy as np
import hashlib
from datetime import datetime

class HypercubeBlock:
    def __init__(self, index, previous_hash, data, timestamp):
        self.index = index
        self.previous_hash = previous_hash
        self.data = data
        self.timestamp = timestamp
        self.hash = self.calculate_hash()

    def calculate_hash(self):
        # Create hypercube hash using 4D coordinates
        hypercube = np.random.rand(4, 4)
        data_bytes = str(self.index) + self.previous_hash + str(self.data) + str(self.timestamp)
        data_array = np.frombuffer(data_bytes.encode(), dtype=np.uint8)[:4]
        hash_value = np.dot(hypercube, data_array)
        return hashlib.sha256(hash_value.tobytes()).hexdigest()

class HypercubeBlockchain:
    def __init__(self):
        self.chain = [self.create_genesis_block()]

    def create_genesis_block(self):
        return HypercubeBlock(0, '0' * 64, 'Genesis Block', datetime.now())

    def get_latest_block(self):
        return self.chain[-1]

    def add_block(self, data):
        latest_block = self.get_latest_block()
        new_block = HypercubeBlock(
            index=latest_block.index + 1,
            previous_hash=latest_block.hash,
            data=data,
            timestamp=datetime.now()
        )
        self.chain.append(new_block)

    def is_chain_valid(self):
        for i in range(1, len(self.chain)):
            current_block = self.chain[i]
            previous_block = self.chain[i - 1]
            if current_block.hash != current_block.calculate_hash():
                return False
            if current_block.previous_hash != previous_block.hash:
                return False
        return True
