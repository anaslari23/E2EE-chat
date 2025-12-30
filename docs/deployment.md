# Deployment & Setup Guide

This guide provides step-by-step instructions for setting up the Secure Chat E2EE application.

## 1. Backend Setup (FastAPI)

### Prerequisites
- Python 3.11+
- Virtualenv

### Steps
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure environment variables:
   - Copy `.env.example` to `.env`.
   - Update `SECRET_KEY` with a secure random string.
5. Run the server:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

## 2. Frontend Setup (Flutter)

### Prerequisites
- Flutter SDK (stable channel)
- An iOS simulator, Android emulator, or physical device.

### Steps
1. Navigate to the project root:
   ```bash
   cd ..
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. (Web App Only) If the backend is running on a different host, update `lib/services/api_service.dart` with the correct `baseUrl`.
4. Run the application:
   ```bash
   flutter run
   ```

## 3. Database Migration
By default, the application uses SQLite. On startup, the `init_db()` function in `app/db/session.py` will automatically create the necessary tables. If using PostgreSQL, ensure the connection string in `.env` is correct.

## 4. Troubleshooting
- **WebSocket Connection Failure**: Ensure the client is connecting to the correct port (default 8000) and that no firewall is blocking WS traffic.
- **Key Generation Error**: Ensure `libsignal_protocol_dart` is correctly installed via `pubspec.yaml`.
