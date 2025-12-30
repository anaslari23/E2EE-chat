# Threat Model: Secure End-to-End Encrypted Chat

This document outlines the security assumptions, identified threats, and mitigations implemented in the system.

## Trust Assumptions
1. **User Devices**: We assume the user's physical device is not compromised. If an attacker has root access to the device, they can extract session keys and plaintext messages from memory or secure storage.
2. **Signal Protocol**: We trust the mathematical foundations of the X3DH key exchange and Double Ratchet algorithm.
3. **TLS/SSL**: We assume that transport-layer security is active, protecting against message modification/injection during transit.

## Identified Threats & Mitigations

### 1. Compromised Backend Server
- **Threat**: An attacker gains full control of the database and backend process.
- **Mitigation**: 
  - **End-to-End Encryption**: The server never sees plaintext. It only sees encrypted blobs (ciphertexts) and public key bundles.
  - **Blind Relay**: The server routes messages without knowing their contents. Even with database access, the attacker cannot read the history.

### 2. Brute-Force Authentication
- **Threat**: An attacker attempts to guess user passwords via the `/login` endpoint.
- **Mitigation**:
  - **Rate Limiting**: Implemented via `Slowapi`. Logins are limited to 10/minute, and registrations to 5/hour per IP.
  - **Secure Hashing**: Passwords are hashed using Argon2/Bcrypt (via `passlib`).

### 3. Metadata Extraction
- **Threat**: An observer (or malicious server) analyzes who is talking to whom and when.
- **Status addressed**: Partially mitigated. While the server must know the recipient ID to route messages, we avoid storing persistent links between users in plaintext more than necessary. Offline messages are transient until delivered.

### 4. Denial of Service (DoS)
- **Threat**: An attacker floods the WebSocket or API with massive amounts of data to exhaust server memory or storage.
- **Mitigation**:
  - **Size Constraints**: Messages are limited to 1MB total, and ciphertexts to 512KB. 
  - **WebSocket Throttling**: Throttling logic ensures a single connection cannot overwhelm the relay.

### 5. Man-in-the-Middle (MitM) Key Substitution
- **Threat**: A malicious server replaces User B's public keys with its own at the time User A fetches them.
- **Status addressed**: This is a known risk in any centralized key directory. Future phases will explore **Safety Numbers (Key Verification)** to allow users to verify identities out-of-band.

## Summary: Security Posture
The system achieves **perfect forward secrecy** and **post-compromise security** for every message. The backend is treated as a "Zero-Trust" entity regarding message content.
