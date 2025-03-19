# TetraCryptPQC Deployment Guide

## 🚀 Quick Deployment

### Prerequisites

1. **System Requirements**
   - Linux/Unix-based system (Ubuntu 20.04+ recommended)
   - 16GB RAM minimum
   - 4 CPU cores minimum
   - 100GB free disk space

2. **Required Software**
   ```bash
   # Install Podman
   sudo apt-get update
   sudo apt-get install -y podman podman-compose

   # Install Node.js 18
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs

   # Install StarkNet DevNet
   pip install starknet-devnet

   # Install Netlify CLI
   npm install -g netlify-cli
   ```

### 🔐 Environment Setup

1. **Clone Repository**
   ```bash
   git clone https://github.com/yourusername/TetraCryptPQC.git
   cd TetraCryptPQC
   ```

2. **Configure Environment**
   ```bash
   # Copy example environment files
   cp .env.example .env
   cp frontend/.env.example frontend/.env

   # Edit environment files with your settings
   nano .env
   nano frontend/.env
   ```

3. **Set Up StarkNet**
   ```bash
   # Install Cairo lang and dependencies
   curl -L https://raw.githubusercontent.com/starkware-libs/cairo-lang/master/scripts/setup.sh | bash
   ```

### 🚀 Deployment

1. **Single Command Deployment**
   ```bash
   # Make deploy script executable
   chmod +x deploy.sh

   # Run deployment
   ./deploy.sh
   ```

2. **Manual Deployment (if needed)**
   ```bash
   # Deploy StarkNet contracts
   starknet deploy --contract contracts/pqc_auth.cairo --network alpha-goerli

   # Deploy backend services
   podman-compose up -d

   # Deploy frontend
   cd frontend
   npm install
   npm run build
   netlify deploy --prod
   ```

### 📊 Monitoring Setup

1. **Access Monitoring**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000

2. **Initial Grafana Setup**
   ```bash
   # Default credentials
   Username: admin
   Password: admin
   ```

3. **Import Dashboards**
   - Go to Grafana -> Dashboards -> Import
   - Import dashboard IDs:
     - 12345 (TetraCryptPQC Overview)
     - 12346 (Security Monitoring)
     - 12347 (Performance Metrics)

### 🔍 Verification

1. **Check Service Status**
   ```bash
   podman ps
   podman-compose ps
   ```

2. **Verify Endpoints**
   - Backend API: http://localhost:5000/health
   - Frontend: https://[your-site].netlify.app
   - StarkNet Node: http://localhost:5050
   - AI Security: http://localhost:5100

3. **Test Cryptographic Operations**
   ```bash
   curl -X POST http://localhost:5000/api/v1/test-encryption \
     -H "Content-Type: application/json" \
     -d '{"data": "test"}'
   ```

### 🚨 Troubleshooting

1. **Common Issues**
   - If services fail to start, check logs:
     ```bash
     podman logs tetracrypt-pqc-backend
     podman logs tetracrypt-starknet
     ```

2. **Security Checks**
   - Verify security settings:
     ```bash
     # Check container security
     podman top tetracrypt-pqc-backend
     
     # Check network isolation
     podman network inspect tetracrypt_net
     ```

3. **Performance Issues**
   - Monitor resource usage:
     ```bash
     podman stats
     ```

### 🔐 Post-Deployment Security

1. **Change Default Credentials**
   - Update Grafana admin password
   - Rotate StarkNet node keys
   - Update API keys

2. **Enable Monitoring Alerts**
   - Configure alert destinations in Prometheus
   - Set up email/Slack notifications

3. **Regular Maintenance**
   - Schedule regular backups
   - Plan security audits
   - Monitor system logs

### 📞 Support

For deployment support:
- Email: support@tetracryptpqc.com
- GitHub Issues: [Create Issue](https://github.com/yourusername/TetraCryptPQC/issues)
- Documentation: [Full Docs](https://docs.tetracryptpqc.com) 