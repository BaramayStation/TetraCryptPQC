import pytest
from src.tke import TetrahedralKeyExchange
from src.qidl_encrypt import QIDLEncryption
from src.rth import RecursiveTesseractHash
from src.hbb_blockchain import HypercubeBlockchain

@pytest.fixture
def tke():
    return TetrahedralKeyExchange()

@pytest.fixture
def qidl():
    return QIDLEncryption()

@pytest.fixture
def rth():
    return RecursiveTesseractHash()

@pytest.fixture
def hbb():
    return HypercubeBlockchain()


def test_tetrahedral_key_exchange(tke):
    key1 = tke.generate_tetrahedral_key()
    key2 = tke.generate_tetrahedral_key()
    assert key1.shape == key2.shape
    assert len(key1) == tke.dimension


def test_qidl_encryption(qidl):
    message = 'Test message'
    encrypted = qidl.encrypt(message)
    decrypted = qidl.decrypt(encrypted)
    assert decrypted == message
    assert len(encrypted) == qidl.dimension


def test_recursive_tesseract_hash(rth):
    data = 'Test data'
    hash_value = rth.recursive_hash(data)
    assert rth.verify_hash(data, hash_value)
    assert len(hash_value) == rth.dimensions


def test_hypercube_blockchain(hbb):
    hbb.add_block('Test data')
    assert hbb.is_chain_valid()
