import numpy as np
from scipy.spatial import ConvexHull

class QIDLEncryption:
    def __init__(self, dimension=4):
        self.dimension = dimension

    def create_icosahedral_structure(self):
        # Generate icosahedral points in n-dimensional space
        phi = (1 + np.sqrt(5)) / 2
        points = np.array([
            [0, 1, phi], [0, -1, phi], [0, 1, -phi], [0, -1, -phi],
            [1, phi, 0], [-1, phi, 0], [1, -phi, 0], [-1, -phi, 0],
            [phi, 0, 1], [-phi, 0, 1], [phi, 0, -1], [-phi, 0, -1]
        ])
        
        # Extend to higher dimensions if needed
        if self.dimension > 3:
            points = np.hstack([points, np.zeros((points.shape[0], self.dimension - 3))])
        
        return points[:self.dimension]  # Ensure consistent dimension

    def encrypt(self, message):
        # Convert message to numerical format
        message_array = np.frombuffer(message.encode(), dtype=np.uint8)
        
        # Create icosahedral structure
        ico_points = self.create_icosahedral_structure()
        
        # Perform encryption using icosahedral geometry
        encrypted = np.dot(ico_points[:len(message_array)], message_array[:self.dimension])
        return encrypted

    def decrypt(self, encrypted):
        # Decrypt message using icosahedral geometry
        ico_points = self.create_icosahedral_structure()
        decrypted = np.linalg.solve(ico_points[:len(encrypted)], encrypted[:self.dimension])
        return bytes(np.round(decrypted).astype(np.uint8)).decode()
