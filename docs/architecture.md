# System Architecture

## Overview
The Secure Chat E2EE system follows a **Blind Relay** architecture. The goal is to maximize privacy by ensuring the server remains as ignorant as possible about the data it handles.

## Core Components

### 1. Flutter Client
- **Signal Logic**: Manages identity keys, pre-key bundles, and session ratchets.
- **Storage**: Uses `flutter_secure_storage` for persisting sensitive session states.
- **State Management**: Powered by `Riverpod` for clean dependency injection and UI synchronization.

### 2. FastAPI Backend
- **Key Directory**: Stores public pre-key bundles for all registered devices.
- **WebSocket Manager**: Tracks active connections by `(user_id, device_id)` and implements fan-out relay.
- **Message Store**: Temporarily holds ciphertexts for offline devices until they connect and sync.

## Data Relationships
- **User**: The primary identity.
- **Device**: A user can have many devices. Each device has its own `registration_id` and unique Signal session with other devices.
- **Session**: A 1-to-1 secure pipe between any two devices.

## Message Flow (Alice to Bob)
1. Alice requests Bob's device list and key bundles from the server.
2. Alice encrypts the message $N$ times for Bob's $N$ devices.
3. Alice sends the $N$ ciphertexts in a single WebSocket payload.
4. Server identifies Bob's online devices and relays the specific ciphertexts.
5. Server stores any undelivered ciphertexts for later retrieval.

## Security Controls
- **Perfect Forward Secrecy**: Ensured by the Double Ratchet algorithm. Every message uses a new key.
- **Post-Compromise Security**: Even if a session key is lost, future messages recover security as soon as a new DH exchange occurs.
- **Zero-Trust Backend**: The backend is assumed to be adversarial. It cannot read messages even if fully compromised.
