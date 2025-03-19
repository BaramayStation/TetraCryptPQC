import numpy as np

class RecursiveTesseractHash:
    def __init__(self, dimensions=4, iterations=3):
        self.dimensions = dimensions
        self.iterations = iterations

    def generate_tesseract(self):
        # Generate tesseract vertices in n-dimensional space
        vertices = np.array(np.meshgrid(*[[-1, 1]] * self.dimensions)).T.reshape(-1, self.dimensions)
        return vertices[:self.dimensions]  # Ensure consistent dimension

    def recursive_hash(self, data):
        # Convert data to numerical format
        data_array = np.frombuffer(data.encode(), dtype=np.uint8)
        
        # Initialize hash value
        hash_value = np.zeros(self.dimensions)
        
        # Perform recursive hashing
        for _ in range(self.iterations):
            tesseract = self.generate_tesseract()
            hash_value = np.dot(tesseract[:len(data_array)], data_array[:self.dimensions])
            data_array = hash_value.astype(np.uint8)
        
        return hash_value

    def verify_hash(self, data, target_hash):
        # Verify hash by comparing with computed hash
        computed_hash = self.recursive_hash(data)
        return np.array_equal(computed_hash, target_hash)
