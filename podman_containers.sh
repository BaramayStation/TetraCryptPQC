#!/bin/bash
# Podman Containers Setup

# Build and run the cryptographic container
podman build -t tetracryptpqc .
podman run -d --name tetracryptpqc_container tetracryptpqc
