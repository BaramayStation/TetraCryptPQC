import * as dgram from 'dgram';
import * as crypto from 'crypto';
import { exec } from 'child_process';
import { promisify } from 'util';
import { EventEmitter } from 'events';

const execAsync = promisify(exec);

interface YggdrasilPeer {
    address: string;
    publicKey: string;
    lastSeen: Date;
    isActive: boolean;
    latency: number;
}

export class YggdrasilMesh extends EventEmitter {
    private peers: Map<string, YggdrasilPeer>;
    private socket: dgram.Socket;
    private readonly PEER_TIMEOUT = 300000; // 5 minutes
    private readonly HEALTH_CHECK_INTERVAL = 60000; // 1 minute
    private isInitialized: boolean = false;

    constructor() {
        super();
        this.peers = new Map();
        this.socket = dgram.createSocket('udp6');
    }

    async initialize(): Promise<void> {
        try {
            // Start Yggdrasil service
            await execAsync('systemctl start yggdrasil');
            
            // Configure firewall
            await execAsync('ip6tables -A INPUT -i ygg0 -j ACCEPT');
            await execAsync('ip6tables -A OUTPUT -o ygg0 -j ACCEPT');
            
            // Setup socket listeners
            this.setupSocketListeners();
            
            // Start health checks
            this.startHealthChecks();
            
            this.isInitialized = true;
            this.emit('ready');
        } catch (error) {
            this.emit('error', error);
            throw error;
        }
    }

    private setupSocketListeners(): void {
        this.socket.on('message', (msg, rinfo) => {
            try {
                const data = JSON.parse(msg.toString());
                this.handleMessage(data, rinfo);
            } catch (error) {
                this.emit('error', `Invalid message format: ${error}`);
            }
        });

        this.socket.on('error', (error) => {
            this.emit('error', `Socket error: ${error}`);
        });
    }

    private async handleMessage(data: any, rinfo: dgram.RemoteInfo): Promise<void> {
        switch (data.type) {
            case 'PEER_ANNOUNCE':
                await this.handlePeerAnnounce(data, rinfo);
                break;
            case 'HEALTH_CHECK':
                await this.handleHealthCheck(data, rinfo);
                break;
            case 'DATA_SYNC':
                await this.handleDataSync(data);
                break;
            case 'EMERGENCY_RECOVERY':
                await this.handleEmergencyRecovery(data);
                break;
            default:
                this.emit('error', `Unknown message type: ${data.type}`);
        }
    }

    private async handlePeerAnnounce(data: any, rinfo: dgram.RemoteInfo): Promise<void> {
        const peer: YggdrasilPeer = {
            address: rinfo.address,
            publicKey: data.publicKey,
            lastSeen: new Date(),
            isActive: true,
            latency: 0
        };

        this.peers.set(data.publicKey, peer);
        this.emit('peer:joined', peer);
    }

    private async handleHealthCheck(data: any, rinfo: dgram.RemoteInfo): Promise<void> {
        const peer = this.peers.get(data.publicKey);
        if (peer) {
            peer.lastSeen = new Date();
            peer.latency = Date.now() - data.timestamp;
            this.peers.set(data.publicKey, peer);
        }
    }

    private async handleDataSync(data: any): Promise<void> {
        try {
            // Verify data signature
            const isValid = this.verifySignature(data.payload, data.signature, data.publicKey);
            if (!isValid) {
                throw new Error('Invalid data signature');
            }

            // Process synchronized data
            await this.processSyncedData(data.payload);
            this.emit('data:synced', data.payload);
        } catch (error) {
            this.emit('error', `Data sync error: ${error}`);
        }
    }

    private async handleEmergencyRecovery(data: any): Promise<void> {
        try {
            // Verify recovery request
            if (this.verifyRecoveryRequest(data)) {
                // Initiate emergency recovery protocol
                await this.initiateEmergencyRecovery(data);
                this.emit('recovery:completed', data.nodeId);
            }
        } catch (error) {
            this.emit('error', `Recovery error: ${error}`);
        }
    }

    private verifySignature(data: any, signature: string, publicKey: string): boolean {
        try {
            const verify = crypto.createVerify('SHA384');
            verify.update(JSON.stringify(data));
            return verify.verify(publicKey, signature, 'base64');
        } catch {
            return false;
        }
    }

    private async processSyncedData(data: any): Promise<void> {
        // Implement data processing logic
        // This could include updating local state, database, etc.
    }

    private verifyRecoveryRequest(data: any): boolean {
        // Implement recovery request verification
        return true; // Placeholder
    }

    private async initiateEmergencyRecovery(data: any): Promise<void> {
        // Implement emergency recovery protocol
    }

    private startHealthChecks(): void {
        setInterval(() => {
            this.checkPeersHealth();
        }, this.HEALTH_CHECK_INTERVAL);
    }

    private async checkPeersHealth(): Promise<void> {
        const now = Date.now();
        for (const [publicKey, peer] of this.peers) {
            if (now - peer.lastSeen.getTime() > this.PEER_TIMEOUT) {
                peer.isActive = false;
                this.emit('peer:inactive', peer);
            }
        }
    }

    // Public API methods
    async broadcastData(data: any): Promise<void> {
        if (!this.isInitialized) {
            throw new Error('YggdrasilMesh not initialized');
        }

        const message = {
            type: 'DATA_SYNC',
            payload: data,
            timestamp: Date.now(),
            signature: this.signData(data)
        };

        for (const peer of this.peers.values()) {
            if (peer.isActive) {
                this.socket.send(
                    JSON.stringify(message),
                    0,
                    message.length,
                    6789,
                    peer.address
                );
            }
        }
    }

    private signData(data: any): string {
        const sign = crypto.createSign('SHA384');
        sign.update(JSON.stringify(data));
        return sign.sign(process.env.PRIVATE_KEY!, 'base64');
    }

    async getPeerStatus(): Promise<Map<string, YggdrasilPeer>> {
        return new Map(this.peers);
    }

    async initiateRecovery(nodeId: string): Promise<void> {
        const message = {
            type: 'EMERGENCY_RECOVERY',
            nodeId,
            timestamp: Date.now()
        };

        await this.broadcastData(message);
    }

    async shutdown(): Promise<void> {
        this.socket.close();
        await execAsync('systemctl stop yggdrasil');
        this.isInitialized = false;
        this.emit('shutdown');
    }
}

// Export singleton instance
export const yggdrasilMesh = new YggdrasilMesh(); 