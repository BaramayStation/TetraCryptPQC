import pytest
from src.tke import TetrahedralKeyExchange
import numpy as np

class TestTetrahedralKeyExchange:
    def setup_method(self):
        self.tke = TetrahedralKeyExchange()

    def test_key_generation(self):
        key = self.tke.generate_tetrahedral_key()
        assert len(key) == 32  # 4 dimensions * 8 bytes per float

    def test_key_exchange(self):
        alice = TetrahedralKeyExchange()
        bob = TetrahedralKeyExchange()
        
        # Simulate key exchange
        alice_public = alice.generate_tetrahedral_key()
        bob_public = bob.generate_tetrahedral_key()
        
        alice_shared = alice.exchange_keys(bob_public)
        bob_shared = bob.exchange_keys(alice_public)
        
        # Verify shared keys match
        assert alice_shared == bob_shared
