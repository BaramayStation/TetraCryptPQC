import unittest
import numpy as np
from ..rth import RecursiveTesseractHash

class TestRecursiveTesseractHash(unittest.TestCase):
    def test_hash(self):
        rth = RecursiveTesseractHash()
        data = np.random.rand(16)
        hashed_data = rth.hash(data)
        self.assertEqual(hashed_data.shape, (16,))

if __name__ == "__main__":
    unittest.main()
