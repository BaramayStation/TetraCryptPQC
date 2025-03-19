import numpy as np
import networkx as nx

class TetrahedralNetwork:
    def __init__(self, dimensions=4):
        self.dimensions = dimensions
        self.graph = nx.Graph()

    def create_tetrahedral_graph(self, depth):
        # Create recursive tetrahedral structure
        for i in range(depth):
            points = np.random.rand(4, self.dimensions)
            tetrahedron = nx.complete_graph(4)
            for j in range(4):
                for k in range(j + 1, 4):
                    self.graph.add_edge(
                        tuple(points[j][:self.dimensions]),
                        tuple(points[k][:self.dimensions]),
                        weight=np.linalg.norm(points[j][:self.dimensions] - points[k][:self.dimensions])
                    )
        return self.graph

    def encrypt_data(self, data):
        # Convert data to numerical format
        data_array = np.frombuffer(data.encode(), dtype=np.uint8)
        
        # Perform encryption using tetrahedral network
        encrypted = np.zeros(self.dimensions)
        for node in self.graph.nodes:
            encrypted += np.dot(node, data_array[:self.dimensions])
        return encrypted

    def decrypt_data(self, encrypted):
        # Decrypt data using tetrahedral network
        decrypted = np.zeros(self.dimensions)
        for node in self.graph.nodes:
            decrypted += np.dot(node, encrypted[:self.dimensions])
        return bytes(np.round(decrypted).astype(np.uint8)).decode()
