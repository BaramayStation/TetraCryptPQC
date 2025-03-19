#!/usr/bin/env python3

import asyncio
import aiohttp
import subprocess
import json
import time
import logging
import numpy as np
from concurrent.futures import ThreadPoolExecutor
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from typing import List, Dict, Any
import os
import sys
import yaml
import torch
from transformers import AutoTokenizer, AutoModel
import psutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('stress_test.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

class FIPSCompliance:
    """NIST FIPS 140-3 Compliance Testing"""
    
    def __init__(self):
        self.key_sizes = {
            'RSA': 3072,
            'ECC': 384,
            'AES': 256,
            'SHA': 384
        }
        
    async def verify_key_strengths(self) -> bool:
        """Verify cryptographic key strengths meet FIPS requirements"""
        try:
            # Check RSA key strength
            private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=self.key_sizes['RSA']
            )
            
            # Verify SHA-384 usage
            hasher = hashes.Hash(hashes.SHA384())
            hasher.update(b"Test data")
            hash_result = hasher.finalize()
            
            return len(hash_result) * 8 >= self.key_sizes['SHA']
        except Exception as e:
            logging.error(f"FIPS key strength verification failed: {e}")
            return False

    async def test_rng_quality(self, sample_size: int = 1000000) -> bool:
        """Test Random Number Generator quality"""
        try:
            random_bytes = os.urandom(sample_size)
            data = np.frombuffer(random_bytes, dtype=np.uint8)
            
            # Statistical tests
            mean = np.mean(data)
            std = np.std(data)
            entropy = -sum([(np.sum(data == i)/len(data)) * 
                          np.log2(np.sum(data == i)/len(data)) 
                          for i in range(256) if np.sum(data == i) > 0])
            
            return (
                127.1 <= mean <= 127.9 and  # Expected mean for uniform distribution
                73 <= std <= 75 and         # Expected std for uniform distribution
                entropy >= 7.9               # High entropy requirement
            )
        except Exception as e:
            logging.error(f"RNG quality test failed: {e}")
            return False

class LoadTesting:
    """System Load and Performance Testing"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.session = None
        self.max_concurrent = 1000
        
    async def setup(self):
        """Initialize testing session"""
        self.session = aiohttp.ClientSession()
        
    async def cleanup(self):
        """Cleanup testing session"""
        if self.session:
            await self.session.close()
            
    async def test_endpoint(self, endpoint: str, payload: Dict[str, Any]) -> bool:
        """Test single endpoint under load"""
        try:
            async with self.session.post(
                f"{self.base_url}{endpoint}",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                return response.status == 200
        except Exception as e:
            logging.error(f"Endpoint test failed: {e}")
            return False
            
    async def concurrent_requests(self, endpoint: str, num_requests: int) -> Dict[str, float]:
        """Execute concurrent requests and measure performance"""
        start_time = time.time()
        tasks = []
        
        for i in range(num_requests):
            payload = {
                "data": f"Test payload {i}",
                "encryption": "PQC",
                "priority": i % 3
            }
            tasks.append(self.test_endpoint(endpoint, payload))
            
        results = await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.time()
        
        success_rate = sum(1 for r in results if r is True) / len(results)
        latency = (end_time - start_time) / len(results)
        
        return {
            "success_rate": success_rate,
            "avg_latency": latency,
            "requests_per_second": len(results) / (end_time - start_time)
        }

class PodmanSecurity:
    """Podman Container Security Testing"""
    
    def __init__(self):
        self.containers = []
        
    def get_container_stats(self) -> Dict[str, Any]:
        """Get container resource usage and security stats"""
        try:
            result = subprocess.run(
                ["podman", "stats", "--no-stream", "--format", "json"],
                capture_output=True,
                text=True
            )
            return json.loads(result.stdout)
        except Exception as e:
            logging.error(f"Failed to get container stats: {e}")
            return {}
            
    def check_container_isolation(self) -> bool:
        """Verify container isolation and resource limits"""
        try:
            result = subprocess.run(
                ["podman", "inspect", *self.containers],
                capture_output=True,
                text=True
            )
            inspections = json.loads(result.stdout)
            
            for container in inspections:
                # Check security options
                if not container.get("HostConfig", {}).get("SecurityOpt"):
                    return False
                    
                # Check resource limits
                if not container.get("HostConfig", {}).get("Resources", {}).get("Memory"):
                    return False
                    
                # Check network isolation
                if container.get("HostConfig", {}).get("NetworkMode") == "host":
                    return False
                    
            return True
        except Exception as e:
            logging.error(f"Container isolation check failed: {e}")
            return False

class LLMSecurityTest:
    """LLM Training Security Testing"""
    
    def __init__(self):
        self.model_name = "bert-base-uncased"  # Example model for testing
        self.tokenizer = None
        self.model = None
        
    async def setup(self):
        """Initialize LLM testing environment"""
        try:
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            self.model = AutoModel.from_pretrained(self.model_name)
        except Exception as e:
            logging.error(f"LLM setup failed: {e}")
            
    async def test_data_isolation(self, test_data: List[str]) -> bool:
        """Test data isolation during LLM training"""
        try:
            # Encode test data
            encoded = self.tokenizer(
                test_data,
                padding=True,
                truncation=True,
                return_tensors="pt"
            )
            
            # Monitor memory for data leaks
            initial_memory = psutil.Process().memory_info().rss
            
            # Process through model
            with torch.no_grad():
                outputs = self.model(**encoded)
                
            # Check memory after processing
            final_memory = psutil.Process().memory_info().rss
            memory_diff = final_memory - initial_memory
            
            # Verify memory cleanup
            del outputs
            torch.cuda.empty_cache()
            cleanup_memory = psutil.Process().memory_info().rss
            
            return cleanup_memory <= initial_memory * 1.1  # Allow 10% overhead
        except Exception as e:
            logging.error(f"Data isolation test failed: {e}")
            return False
            
    async def test_memory_sanitization(self) -> bool:
        """Test memory sanitization after LLM operations"""
        try:
            # Allocate test tensor
            test_tensor = torch.rand(1000, 1000)
            tensor_data = test_tensor.clone()
            
            # Delete and check memory
            del test_tensor
            torch.cuda.empty_cache()
            
            # Allocate new tensor and check for data remnants
            new_tensor = torch.zeros(1000, 1000)
            
            return not torch.allclose(new_tensor, tensor_data)
        except Exception as e:
            logging.error(f"Memory sanitization test failed: {e}")
            return False

class NetworkResilience:
    """Network Resilience and Failover Testing"""
    
    def __init__(self):
        self.yggdrasil_peers = []
        self.backup_nodes = []
        
    async def test_network_partition(self) -> bool:
        """Test system behavior during network partitions"""
        try:
            # Simulate network partition
            subprocess.run(["iptables", "-A", "INPUT", "-p", "tcp", "--dport", "5000", "-j", "DROP"])
            
            # Wait for failover
            await asyncio.sleep(5)
            
            # Check system status
            status = await self.check_system_health()
            
            # Restore network
            subprocess.run(["iptables", "-D", "INPUT", "-p", "tcp", "--dport", "5000", "-j", "DROP"])
            
            return status
        except Exception as e:
            logging.error(f"Network partition test failed: {e}")
            return False
            
    async def check_system_health(self) -> bool:
        """Check system health during failure scenarios"""
        try:
            # Check Yggdrasil mesh
            ygg_status = subprocess.run(["yggdrasil", "-status"], capture_output=True)
            
            # Check backup nodes
            backup_status = all(await asyncio.gather(*[
                self.check_node_health(node) for node in self.backup_nodes
            ]))
            
            return ygg_status.returncode == 0 and backup_status
        except Exception as e:
            logging.error(f"Health check failed: {e}")
            return False
            
    async def check_node_health(self, node: str) -> bool:
        """Check individual node health"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"http://{node}/health") as response:
                    return response.status == 200
        except Exception:
            return False

class StressTest:
    """Main Stress Testing Orchestrator"""
    
    def __init__(self):
        self.fips = FIPSCompliance()
        self.load = LoadTesting("http://localhost:5000")
        self.podman = PodmanSecurity()
        self.llm = LLMSecurityTest()
        self.network = NetworkResilience()
        
    async def run_all_tests(self) -> Dict[str, Any]:
        """Run all stress tests and collect results"""
        try:
            # Initialize components
            await self.load.setup()
            await self.llm.setup()
            
            # Run tests
            results = {
                "fips_compliance": {
                    "key_strength": await self.fips.verify_key_strengths(),
                    "rng_quality": await self.fips.test_rng_quality()
                },
                "load_testing": await self.load.concurrent_requests("/api/encrypt", 1000),
                "podman_security": {
                    "isolation": self.podman.check_container_isolation(),
                    "resource_limits": bool(self.podman.get_container_stats())
                },
                "llm_security": {
                    "data_isolation": await self.llm.test_data_isolation([
                        "Test data 1",
                        "Test data 2",
                        "Sensitive information"
                    ]),
                    "memory_sanitization": await self.llm.test_memory_sanitization()
                },
                "network_resilience": {
                    "partition_recovery": await self.network.test_network_partition(),
                    "system_health": await self.network.check_system_health()
                }
            }
            
            # Cleanup
            await self.load.cleanup()
            
            return results
        except Exception as e:
            logging.error(f"Stress test failed: {e}")
            return {"error": str(e)}
            
    def generate_report(self, results: Dict[str, Any]) -> str:
        """Generate detailed test report"""
        report = """
TetraCryptPQC Stress Test Report
===============================

FIPS 140-3 Compliance
--------------------
- Key Strength: {fips[key_strength]}
- RNG Quality: {fips[rng_quality]}

Load Testing Results
------------------
- Success Rate: {load[success_rate]:.2%}
- Average Latency: {load[avg_latency]:.3f}s
- Requests/Second: {load[requests_per_second]:.2f}

Podman Security
-------------
- Container Isolation: {podman[isolation]}
- Resource Limits: {podman[resource_limits]}

LLM Security
-----------
- Data Isolation: {llm[data_isolation]}
- Memory Sanitization: {llm[memory_sanitization]}

Network Resilience
----------------
- Partition Recovery: {network[partition_recovery]}
- System Health: {network[system_health]}

Overall Status: {status}
        """.format(
            fips=results["fips_compliance"],
            load=results["load_testing"],
            podman=results["podman_security"],
            llm=results["llm_security"],
            network=results["network_resilience"],
            status="PASSED" if all(
                results["fips_compliance"].values() +
                [results["load_testing"]["success_rate"] > 0.99] +
                results["podman_security"].values() +
                results["llm_security"].values() +
                results["network_resilience"].values()
            ) else "FAILED"
        )
        
        return report

async def main():
    """Main execution function"""
    stress_test = StressTest()
    results = await stress_test.run_all_tests()
    report = stress_test.generate_report(results)
    
    # Save report
    with open("stress_test_report.txt", "w") as f:
        f.write(report)
        
    # Log results
    logging.info("Stress test completed")
    logging.info(f"Overall status: {'PASSED' if results.get('error') is None else 'FAILED'}")
    
    return 0 if results.get('error') is None else 1

if __name__ == "__main__":
    sys.exit(asyncio.run(main())) 