import unittest
import numpy as np
from ..qidl_encrypt import QIDLEncryption

class TestQIDLEncryption(unittest.TestCase):
    def test_encrypt(self):
        qidl = QIDLEncryption()
        data = np.random.rand(20)
        encrypted_data = qidl.encrypt(data)
        self.assertEqual(encrypted_data.shape, (12,))

if __name__ == "__main__":
    unittest.main()
