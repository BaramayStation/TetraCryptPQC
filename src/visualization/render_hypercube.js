/**
 * TetraCryptPQC: WebGPU-based Tesseract Renderer
 * Modern implementation using Three.js and WebGPU for cryptographic visualization
 */

import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
import { GUI } from 'three/examples/jsm/libs/lil-gui.module.min.js';
import { WebGPURenderer } from 'three/examples/jsm/renderers/webgpu/WebGPURenderer.js';
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

export class CryptoVisualizer {
    constructor(container) {
        this.container = container;
        this.dimensions = 4; // 4D for tesseract
        this.init();
    }

    async init() {
        // Check WebGPU support
        if (!navigator.gpu) {
            throw new Error('WebGPU not supported');
        }

        await this.setupWebGPU();
        this.setupScene();
        this.setupTesseract();
        this.setupGUI();
        this.animate();

        window.addEventListener('resize', () => this.onResize());
    }

    async setupWebGPU() {
        // Initialize WebGPU renderer
        this.renderer = new WebGPURenderer();
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        this.container.appendChild(this.renderer.domElement);

        // Get WebGPU adapter and device
        const adapter = await navigator.gpu.requestAdapter();
        this.device = await adapter.requestDevice();

        // Create shader modules
        this.vertexShader = this.device.createShaderModule({
            code: `
                struct VertexOutput {
                    @builtin(position) position: vec4<f32>,
                    @location(0) color: vec4<f32>,
                };

                @vertex
                fn main(
                    @location(0) position: vec4<f32>,
                    @location(1) color: vec4<f32>
                ) -> VertexOutput {
                    var output: VertexOutput;
                    output.position = position;
                    output.color = color;
                    return output;
                }
            `
        });

        this.fragmentShader = this.device.createShaderModule({
            code: `
                @fragment
                fn main(@location(0) color: vec4<f32>) -> @location(0) vec4<f32> {
                    return color;
                }
            `
        });
    }

    setupScene() {
        this.scene = new THREE.Scene();
        this.camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        this.camera.position.set(3, 3, 5);

        // Add lighting
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
        this.scene.add(ambientLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(5, 5, 5);
        directionalLight.castShadow = true;
        this.scene.add(directionalLight);

        // Setup controls
        this.controls = new OrbitControls(this.camera, this.renderer.domElement);
        this.controls.enableDamping = true;
        this.controls.dampingFactor = 0.05;
    }

    setupTesseract() {
        // Create tesseract geometry
        const vertices = this.generateTesseractVertices();
        const geometry = new THREE.BufferGeometry();
        
        // Add vertices
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices.positions, 3));
        geometry.setAttribute('color', new THREE.Float32BufferAttribute(vertices.colors, 3));
        
        // Add edges
        geometry.setIndex(vertices.indices);
        
        // Create material with custom shader
        const material = new THREE.ShaderMaterial({
            vertexShader: `
                varying vec3 vColor;
                void main() {
                    vColor = color;
                    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
                }
            `,
            fragmentShader: `
                varying vec3 vColor;
                void main() {
                    gl_FragColor = vec4(vColor, 1.0);
                }
            `,
            vertexColors: true,
            wireframe: true
        });

        this.tesseract = new THREE.Mesh(geometry, material);
        this.scene.add(this.tesseract);
    }

    generateTesseractVertices() {
        const positions = [];
        const colors = [];
        const indices = [];
        
        // Generate 4D vertices
        for (let x = -1; x <= 1; x += 2) {
            for (let y = -1; y <= 1; y += 2) {
                for (let z = -1; z <= 1; z += 2) {
                    for (let w = -1; w <= 1; w += 2) {
                        positions.push(x, y, z);
                        colors.push(0.5 + x/2, 0.5 + y/2, 0.5 + z/2);
                    }
                }
            }
        }

        // Generate edges
        for (let i = 0; i < 16; i++) {
            for (let j = i + 1; j < 16; j++) {
                let diffCount = 0;
                for (let k = 0; k < 4; k++) {
                    const coord1 = Math.floor(i / Math.pow(2, k)) % 2;
                    const coord2 = Math.floor(j / Math.pow(2, k)) % 2;
                    if (coord1 !== coord2) diffCount++;
                }
                if (diffCount === 1) {
                    indices.push(i, j);
                }
            }
        }

        return { positions, colors, indices };
    }

    setupGUI() {
        this.gui = new GUI();
        this.params = {
            rotationSpeed: 0.001,
            wireframe: true,
            color: '#00ff00'
        };

        this.gui.add(this.params, 'rotationSpeed', 0, 0.01);
        this.gui.add(this.params, 'wireframe').onChange((value) => {
            this.tesseract.material.wireframe = value;
        });
        this.gui.addColor(this.params, 'color').onChange((value) => {
            this.tesseract.material.color.set(value);
        });
    }

    updateTesseract(cryptoEvent) {
        // Update tesseract based on cryptographic events
        const rotation = new THREE.Quaternion();
        rotation.setFromAxisAngle(
            new THREE.Vector3(
                Math.sin(cryptoEvent.entropy),
                Math.cos(cryptoEvent.entropy),
                Math.tan(cryptoEvent.entropy)
            ),
            this.params.rotationSpeed
        );

        this.tesseract.quaternion.multiply(rotation);
    }

    animate() {
        requestAnimationFrame(() => this.animate());

        // Simulate cryptographic event
        const cryptoEvent = {
            entropy: performance.now() * 0.001
        };

        this.updateTesseract(cryptoEvent);
        this.controls.update();
        this.renderer.render(this.scene, this.camera);
    }

    onResize() {
        this.camera.aspect = window.innerWidth / window.innerHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(window.innerWidth, window.innerHeight);
    }

    // API for cryptographic event visualization
    visualizeCryptoEvent(event) {
        // Update visualization based on real cryptographic events
        const { type, data, timestamp } = event;
        
        switch(type) {
            case 'key_generation':
                this.params.rotationSpeed = data.entropy * 0.01;
                break;
            case 'encryption':
                this.tesseract.material.color.setHSL(data.strength, 1, 0.5);
                break;
            case 'blockchain_validation':
                this.params.wireframe = !this.params.wireframe;
                break;
        }
    }
}

// Export for use in the main application
export default CryptoVisualizer;
