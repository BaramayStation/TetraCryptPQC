#!/bin/bash

# TetraCryptPQC Security Audit Script
echo "🔒 Starting Security Audit..."

# Check Yggdrasil network security
check_yggdrasil() {
    echo "📡 Checking Yggdrasil network..."
    
    # Verify Yggdrasil is running
    if ! systemctl is-active --quiet yggdrasil; then
        echo "❌ Yggdrasil service is not running"
        return 1
    fi
    
    # Check for unauthorized peers
    authorized_peers=$(cat config/yggdrasil/authorized_peers.txt 2>/dev/null || echo "")
    current_peers=$(yggdrasil -peers)
    
    for peer in $current_peers; do
        if ! echo "$authorized_peers" | grep -q "$peer"; then
            echo "⚠️ Unauthorized peer detected: $peer"
            return 1
        fi
    done
    
    # Check network encryption
    if ! yggdrasil -address | grep -q "^200:"; then
        echo "❌ Yggdrasil encryption verification failed"
        return 1
    fi
    
    echo "✅ Yggdrasil network security verified"
    return 0
}

# Check Supabase security
check_supabase() {
    echo "🔐 Checking Supabase security..."
    
    # Verify environment variables
    if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
        echo "❌ Supabase credentials not properly configured"
        return 1
    fi
    
    # Check encryption at rest
    if ! grep -q "encryption_at_rest" config/supabase.ts; then
        echo "❌ Supabase encryption at rest not configured"
        return 1
    fi
    
    # Verify RLS policies
    curl -s "$SUPABASE_URL/rest/v1/rpc/check_rls_policies" \
         -H "apikey: $SUPABASE_KEY" \
         -H "Authorization: Bearer $SUPABASE_KEY" | \
    grep -q "policies_enabled" || {
        echo "❌ Supabase RLS policies not properly configured"
        return 1
    }
    
    echo "✅ Supabase security verified"
    return 0
}

# Check backup node security
check_backup_nodes() {
    echo "💾 Checking backup nodes..."
    
    # Verify backup nodes are running
    for i in {1..3}; do
        if ! podman container inspect backup-node-$i >/dev/null 2>&1; then
            echo "❌ Backup node $i is not running"
            return 1
        fi
    done
    
    # Check backup encryption
    latest_backup=$(ls -t /var/backups/tetracryptpqc/*.gpg 2>/dev/null | head -n1)
    if [ -z "$latest_backup" ]; then
        echo "❌ No encrypted backups found"
        return 1
    fi
    
    # Verify backup integrity
    gpg --list-packets "$latest_backup" >/dev/null 2>&1 || {
        echo "❌ Backup encryption verification failed"
        return 1
    }
    
    echo "✅ Backup node security verified"
    return 0
}

# Check PQC implementation
check_pqc() {
    echo "🔑 Checking post-quantum cryptography implementation..."
    
    # Verify PQC libraries
    if ! npm list | grep -q "dilithium-crystals"; then
        echo "❌ Required PQC library not found"
        return 1
    fi
    
    # Check key sizes
    min_key_size=3072  # Minimum size for quantum resistance
    key_size=$(node -e "const pqc = require('./src/encryption/clifford_pqc'); console.log(pqc.getKeySize())")
    if [ "$key_size" -lt "$min_key_size" ]; then
        echo "❌ PQC key size below recommended minimum"
        return 1
    fi
    
    echo "✅ PQC implementation verified"
    return 0
}

# Check network security
check_network() {
    echo "🌐 Checking network security..."
    
    # Check firewall rules
    if command -v ufw >/dev/null 2>&1; then
        ufw status | grep -q "active" || {
            echo "❌ Firewall is not active"
            return 1
        }
    fi
    
    # Check open ports
    required_ports="5000 5050 5100 3000"
    for port in $required_ports; do
        netstat -tuln | grep -q ":$port " || {
            echo "❌ Required port $port is not open"
            return 1
        }
    done
    
    # Check TLS certificates
    if [ ! -f "config/certs/fullchain.pem" ] || [ ! -f "config/certs/privkey.pem" ]; then
        echo "❌ TLS certificates not found"
        return 1
    fi
    
    echo "✅ Network security verified"
    return 0
}

# Main audit function
main() {
    failures=0
    
    # Run all checks
    check_yggdrasil || ((failures++))
    check_supabase || ((failures++))
    check_backup_nodes || ((failures++))
    check_pqc || ((failures++))
    check_network || ((failures++))
    
    # Final report
    echo "
🔒 Security Audit Summary:
-------------------------"
    if [ $failures -eq 0 ]; then
        echo "✅ All security checks passed!"
        exit 0
    else
        echo "❌ $failures security checks failed!"
        echo "⚠️ Please review the logs and address all security concerns."
        exit 1
    fi
}

# Execute audit
main 