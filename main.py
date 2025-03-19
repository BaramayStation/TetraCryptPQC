# Main Entry Point for TetraCryptPQC Nexus
from src.tke import TetrahedralKeyExchange
from src.qidl_encrypt import QIDLEncryption
from src.rth import RecursiveTesseractHash
from src.hbb_blockchain import HypercubeBlockchain
from yggdrasil_network import YggdrasilNetwork

class TetraCryptPQCNexus:
    def __init__(self):
        self.tke = TetrahedralKeyExchange()
        self.qidl = QIDLEncryption()
        self.rth = RecursiveTesseractHash()
        self.hbb = HypercubeBlockchain()
        self.yggdrasil = YggdrasilNetwork()

    def run(self):
        # Example usage of the system
        key = self.tke.generate_key()
        encrypted_data = self.qidl.encrypt(key)
        hashed_data = self.rth.hash(encrypted_data)
        self.hbb.add_block(hashed_data)
        self.yggdrasil.send_message(hashed_data)

if __name__ == "__main__":
    system = TetraCryptPQCNexus()
    system.run()
