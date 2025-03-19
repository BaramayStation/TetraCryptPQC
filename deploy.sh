#!/bin/bash

# TetraCryptPQC Deployment Script
echo "🚀 Starting TetraCryptPQC Deployment..."

# Check required tools
check_requirements() {
    echo "📋 Checking requirements..."
    command -v podman >/dev/null 2>&1 || { echo "❌ Podman is required but not installed. Aborting." >&2; exit 1; }
    command -v npm >/dev/null 2>&1 || { echo "❌ npm is required but not installed. Aborting." >&2; exit 1; }
    command -v starknet-devnet >/dev/null 2>&1 || { echo "❌ starknet-devnet is required but not installed. Aborting." >&2; exit 1; }
    command -v yggdrasil >/dev/null 2>&1 || { echo "❌ Yggdrasil is required but not installed. Installing..." >&2; install_yggdrasil; }
}

# Install Yggdrasil
install_yggdrasil() {
    echo "📦 Installing Yggdrasil..."
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        curl -o /etc/apt/trusted.gpg.d/yggdrasil.gpg https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/key.gpg
        curl -o /etc/apt/sources.list.d/yggdrasil.list https://neilalexander.s3.dualstack.eu-west-2.amazonaws.com/deb/yggdrasil.list
        apt-get update
        apt-get install yggdrasil
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        dnf copr enable neilalexander/yggdrasil-go
        dnf install yggdrasil
    else
        echo "❌ Unsupported OS for automatic Yggdrasil installation"
        exit 1
    fi
}

# Setup environment
setup_environment() {
    echo "🔧 Setting up environment..."
    
    # Create necessary directories
    mkdir -p backend/keys
    mkdir -p frontend/dist
    mkdir -p ai/models
    mkdir -p config/yggdrasil
    mkdir -p config/supabase
    
    # Set permissions for Podman volumes
    sudo chown 1000:1000 backend/keys
    sudo chown 1000:1000 ai/models
    
    # Generate Yggdrasil keys
    yggdrasil -genconf > config/yggdrasil/yggdrasil.conf
    
    # Setup Supabase environment
    if [ ! -f .env ]; then
        echo "SUPABASE_URL=your_supabase_url" > .env
        echo "SUPABASE_KEY=your_supabase_key" >> .env
        echo "⚠️ Please update .env with your Supabase credentials"
    fi
}

# Configure Yggdrasil mesh network
setup_yggdrasil() {
    echo "🌐 Setting up Yggdrasil mesh network..."
    
    # Start Yggdrasil service
    systemctl enable yggdrasil
    systemctl start yggdrasil
    
    # Configure firewall for Yggdrasil
    if command -v ufw >/dev/null 2>&1; then
        ufw allow in on ygg0
        ufw allow out on ygg0
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --zone=public --add-interface=ygg0
        firewall-cmd --reload
    fi
    
    # Wait for network to initialize
    sleep 5
    
    # Verify Yggdrasil connection
    if ! yggdrasil -address; then
        echo "❌ Yggdrasil network setup failed"
        exit 1
    fi
}

# Deploy StarkNet contracts
deploy_starknet() {
    echo "🔗 Deploying StarkNet contracts..."
    
    # Start local StarkNet node if in development
    if [ "$ENVIRONMENT" = "development" ]; then
        starknet-devnet --host 0.0.0.0 --port 5050 --seed 42 &
        STARKNET_PID=$!
        sleep 5  # Wait for node to start
    fi
    
    # Deploy contract
    echo "📄 Deploying PQC Authentication contract..."
    starknet deploy --contract contracts/pqc_auth.cairo --network ${STARKNET_NETWORK:-alpha-goerli}
}

# Deploy Podman containers
deploy_podman() {
    echo "🐋 Deploying Podman containers..."
    
    # Build images
    podman-compose build
    
    # Start services
    podman-compose up -d
    
    # Wait for services to be healthy
    echo "⏳ Waiting for services to be healthy..."
    sleep 10
    
    # Check service health
    podman ps --format "{{.Names}}: {{.Status}}"
}

# Deploy frontend to Netlify
deploy_frontend() {
    echo "🌐 Deploying frontend to Netlify..."
    
    # Install dependencies
    cd frontend
    npm install
    
    # Build frontend
    npm run build
    
    # Deploy to Netlify
    npx netlify-cli deploy --prod --dir=dist
    
    cd ..
}

# Setup monitoring
setup_monitoring() {
    echo "📊 Setting up monitoring..."
    
    # Deploy Prometheus
    podman run -d \
        --name prometheus \
        --network tetracrypt_net \
        -p 9090:9090 \
        -v ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
        prom/prometheus
        
    # Deploy Grafana
    podman run -d \
        --name grafana \
        --network tetracrypt_net \
        -p 3000:3000 \
        -v ./monitoring/grafana:/var/lib/grafana \
        grafana/grafana
}

# Setup decentralized storage
setup_storage() {
    echo "💾 Setting up decentralized storage..."
    
    # Initialize Supabase client
    cd backend
    npm install @supabase/supabase-js
    
    # Setup backup nodes
    for i in {1..3}; do
        podman run -d \
            --name backup-node-$i \
            --network tetracrypt_net \
            -v ./backup:/data \
            tetracrypt-backup
    done
    
    cd ..
}

# Setup failsafe mechanisms
setup_failsafe() {
    echo "🔒 Setting up failsafe mechanisms..."
    
    # Create backup scripts
    cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Automated backup script
timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="/var/backups/tetracryptpqc"
mkdir -p "$backup_dir"

# Backup critical data
tar -czf "$backup_dir/backup_$timestamp.tar.gz" \
    backend/keys \
    config \
    contracts

# Encrypt backup
gpg --encrypt --recipient security@tetracryptpqc.com \
    "$backup_dir/backup_$timestamp.tar.gz"

# Distribute to backup nodes
for node in $(yggdrasil -peers); do
    scp "$backup_dir/backup_$timestamp.tar.gz.gpg" "$node:/backups/"
done
EOF
    
    chmod +x scripts/backup.sh
    
    # Setup automatic backups
    (crontab -l 2>/dev/null; echo "0 */6 * * * /path/to/scripts/backup.sh") | crontab -
}

# Main deployment function
main() {
    # Start time measurement
    start_time=$(date +%s)
    
    # Check requirements
    check_requirements
    
    # Setup environment
    setup_environment
    
    # Setup Yggdrasil network
    setup_yggdrasil
    
    # Deploy components
    deploy_starknet
    deploy_podman
    deploy_frontend
    setup_monitoring
    setup_storage
    setup_failsafe
    
    # Calculate deployment time
    end_time=$(date +%s)
    deployment_time=$((end_time - start_time))
    
    echo "✅ Deployment completed in ${deployment_time} seconds!"
    echo "
🔐 TetraCryptPQC System Status:
--------------------------------
📡 Backend API: http://localhost:5000
🌐 Frontend: https://tetracryptpqc.netlify.app
⛓️ StarkNet Node: http://localhost:5050
🤖 AI Security: http://localhost:5100
📊 Monitoring: http://localhost:3000
🌐 Yggdrasil Address: $(yggdrasil -address)
💾 Backup Nodes: Active
"

    # Final security checks
    echo "🔒 Running security checks..."
    ./scripts/security_audit.sh
}

# Handle errors
handle_error() {
    echo "❌ Error occurred in deployment. Rolling back..."
    
    # Stop services
    podman-compose down
    systemctl stop yggdrasil
    
    # Clean up
    if [ ! -z "$STARKNET_PID" ]; then
        kill $STARKNET_PID
    fi
    
    # Notify administrators
    if [ -f .env ]; then
        source .env
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"⚠️ Deployment failed! Check logs at $(hostname)\"}" \
             $ALERT_WEBHOOK_URL
    fi
    
    exit 1
}

# Set error handler
trap 'handle_error' ERR

# Execute deployment
main 