# Secure Chat E2EE

A state-of-the-art, cross-platform chat application with full End-to-End Encryption (E2EE) powered by the Signal Protocol.

## 🚀 Key Features
- **True E2EE**: Every message is encrypted and decrypted only on user devices. The server never has access to plaintext.
- **Signal Protocol**: Implements the X3DH key exchange and Double Ratchet algorithm for perfect forward secrecy.
- **Multi-Device Support**: A single user can have multiple devices (e.g., Phone and Desktop) with a unified chat history.
- **Blind Relay Backend**: The backend acts as a zero-knowledge router, handling only encrypted blobs and metadata.
- **Offline Messaging**: Reliability ensured with a server-side message queue for targeted device delivery.
- **Security Hardened**: Rate limiting, size constraints, and protection against brute-force attacks.

## 📂 Project Structure
- **/backend**: FastAPI server with asynchronous SQLModel and WebSocket relay.
- **/lib**: Flutter application logic including multi-device Signal implementation.
- **/docs**: Comprehensive documentation on architecture, threat modeling, and deployment.

## 📚 Documentation
- [Architecture & Design](docs/architecture.md) (Internal/Manual Reference)
- [Threat Model](docs/threat_model.md)
- [Deployment & Setup Guide](docs/deployment.md)

## 🛠 Tech Stack
- **Frontend**: Flutter, Riverpod, libsignal_protocol_dart.
- **Backend**: FastAPI, SQLModel (SQLAlchemy 2.0/Pydantic), uvicorn.
- **Security**: Argon2, JWT, Slowapi (Rate Limiting).

## 🧑‍💻 Quick Start
See the [Deployment Guide](docs/deployment.md) for detailed instructions on how to get the project running locally.
