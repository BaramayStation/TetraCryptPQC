#!/bin/bash

# TetraCryptPQC Stress Test Runner
set -e

echo "🚀 Preparing TetraCryptPQC Stress Test Environment..."

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (required for network tests and container management)"
    exit 1
fi

# Setup Python virtual environment
echo "📦 Setting up Python virtual environment..."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Check required system tools
echo "🔍 Checking system requirements..."
command -v podman >/dev/null 2>&1 || { echo "❌ Podman is required but not installed"; exit 1; }
command -v yggdrasil >/dev/null 2>&1 || { echo "❌ Yggdrasil is required but not installed"; exit 1; }
command -v iptables >/dev/null 2>&1 || { echo "❌ iptables is required but not installed"; exit 1; }

# Backup existing Podman containers
echo "💾 Backing up current container state..."
podman ps -a --format "{{.ID}} {{.Names}}" > container_backup.txt

# Stop existing containers
echo "🛑 Stopping existing containers..."
podman stop $(podman ps -aq) 2>/dev/null || true

# Clean system state
echo "🧹 Cleaning system state..."
sync && echo 3 > /proc/sys/vm/drop_caches
swapoff -a && swapon -a
systemctl restart yggdrasil

# Configure system for testing
echo "⚙️ Configuring system for testing..."
ulimit -n 65535  # Increase file descriptor limit
sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.tcp_max_syn_backlog=65535

# Start monitoring
echo "📊 Starting monitoring..."
mkdir -p logs
start_time=$(date +%Y%m%d_%H%M%S)

# CPU monitoring
top -b -n 1 > "logs/cpu_${start_time}.log" &
TOP_PID=$!

# Memory monitoring
free -m > "logs/memory_${start_time}.log"
vmstat 1 > "logs/vmstat_${start_time}.log" &
VMSTAT_PID=$!

# Network monitoring
sar -n DEV 1 > "logs/network_${start_time}.log" &
SAR_PID=$!

# Run stress tests
echo "🔥 Running stress tests..."
python3 stress_test.py

# Collect results
echo "📝 Collecting test results..."
mkdir -p results/${start_time}
cp stress_test_report.txt "results/${start_time}/"
cp stress_test.log "results/${start_time}/"
cp logs/* "results/${start_time}/"

# Stop monitoring
kill $TOP_PID $VMSTAT_PID $SAR_PID

# Restore system state
echo "🔄 Restoring system state..."
while read container; do
    if [ ! -z "$container" ]; then
        podman start $(echo $container | cut -d' ' -f1)
    fi
done < container_backup.txt

# Cleanup
rm container_backup.txt
rm -rf logs

# Generate final report
echo "📊 Generating final report..."
cat > "results/${start_time}/system_info.txt" << EOF
TetraCryptPQC Stress Test Results
================================
Date: $(date)
System Information:
- CPU: $(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d: -f2)
- Memory: $(free -h | grep Mem | awk '{print $2}')
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- Kernel: $(uname -r)
- Podman Version: $(podman version | grep Version | head -n1)
- Yggdrasil Version: $(yggdrasil -version)

Test Summary:
------------
$(cat "results/${start_time}/stress_test_report.txt")

System Metrics:
--------------
$(cat "results/${start_time}/cpu_${start_time}.log" | head -n5)
$(cat "results/${start_time}/memory_${start_time}.log" | head -n3)
EOF

echo "✅ Stress testing completed!"
echo "📁 Results available in: results/${start_time}/"

# Check for test failures
if grep -q "FAILED" "results/${start_time}/stress_test_report.txt"; then
    echo "❌ Some tests failed. Please review the results."
    exit 1
else
    echo "✅ All tests passed!"
    exit 0
fi 