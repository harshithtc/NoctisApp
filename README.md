<div align="center">

# 🌙 NoctisApp

### Encrypted Chat Platform (MVP Beta)

[![Status](https://img.shields.io/badge/Status-MVP%20Beta-yellow)]()
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE.txt)
[![Flutter](https://img.shields.io/badge/Flutter-3.19.0+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109.0+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![API Docs](https://img.shields.io/badge/API%20Docs-Swagger-0A7EA2?logo=swagger&logoColor=white)](http://localhost:8000/docs)
[![Development](https://img.shields.io/badge/Development-Active-green)]()

**Secure • Private • Cross-Platform • In Active Development**

[Current Status](#-current-status) • [Features](#-implemented-features) • [Quick Start](#-quick-start) • [Installation](#-installation) • [Roadmap](#-roadmap)

</div>

---

## ⚠️ IMPORTANT NOTICE - PROPRIETARY SOFTWARE

**This is proprietary software owned by Harshith TC. This repository is public for portfolio and educational purposes only.**

- ✅ You MAY view and learn from the code
- ❌ You MAY NOT distribute, commercialize, or deploy this software
- 📧 For licensing: [harshithtc30@gmail.com](mailto:harshithtc30@gmail.com)

**All patent rights reserved by Harshith TC.**

---

## 📋 Table of Contents

- [Current Status](#-current-status)
- [Overview](#-overview)
- [Implemented Features](#-implemented-features)
- [Quick Start](#-quick-start)
- [Technology Stack](#-technology-stack)
- [Architecture](#-architecture)
- [Security](#-security)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Known Limitations](#️-known-limitations)
- [Roadmap](#-roadmap)
- [API Documentation](#-api-documentation)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

---

## 📍 Current Status

**Version:** 0.9.0 Beta  
**Last Updated:** October 13, 2025  
**Status:** Core functionality working, MVP in testing

### What's Working ✅
- Authentication with OTP verification
- WebSocket-based real-time chat
- Client-side AES-256-GCM encryption
- Offline message queue/sync
- Android, iOS, Web, desktop-ready code
- Material Design 3, light/dark modes
- Message status/typing/read indicators

### In Progress 🚧
- Media uploads (backend ready, frontend testing)
- Push notifications, full test coverage

### Planned 📅
- Voice messages, calls, reactions, self-destruct, desktop optimization, biometrics

---

## 🎯 Overview

**NoctisApp** is an end-to-end encrypted messenger for private, cross-platform communications, built with Flutter and FastAPI.

### Why NoctisApp?
- **🔒 End-to-end encryption**
- **📱 Multi-platform (Flutter: Android, iOS, Web)**
- **⚡ Real-time, offline-first**
- **🎨 Modern UI**

---

## ✨ Implemented Features

### Core Messaging
- AES-256-GCM chat
- Offline queue
- Message status: Queued, Sent, Delivered, Read
- Typing indicators, Read receipts
- Message history (offline access)
- Copy-to-clipboard

### Security & Auth
- Email/password with OTP
- Password strength & hashing (bcrypt)
- JWTs with refresh/expiry
- Device session management
- Hive-encrypted local storage

### UI/UX
- Material Design 3, dark/light
- Animated chat bubbles
- Responsive, accessible layouts
- Connection and status banners

### Platform Status

| Platform | Status  | Ready For          |
|----------|---------|-------------------|
| Android  | ✅      | Dev/Test          |
| iOS      | ✅      | Dev/Test (macOS)  |
| Web (PWA)| ✅      | Dev/Test          |
| Windows/macOS/Linux | 🚧 | Code ready, not configured |

---

## 🚀 Quick Start

### Requirements

- **Flutter 3.19+** — [Install guide](https://flutter.dev/docs/get-started/install)
- **Python 3.11+** — [Download](https://www.python.org/downloads/)
- **Docker, Docker Compose**
- **Git**

### One-command local dev (recommended):

docker-compose up --build

text

- Brings up FastAPI, PostgreSQL, migrations, and backend in one go.

---

## 🛠 Technology Stack

### Frontend
| Technology            | Purpose            |
|-----------------------|--------------------|
| Flutter (3.19+)       | Multi-platform UI  |
| Dart (3.2+)           | Programming language |
| Provider              | State management   |
| Hive                  | Local secure DB    |
| Dio                   | Networking         |
| web_socket_channel    | WebSockets         |
| encrypt               | AES, secure storage|
| Material Design 3     | UI framework       |

### Backend
| Technology         | Purpose           |
|--------------------|-------------------|
| FastAPI (0.109+)   | Async web API     |
| Python (3.11+)     | Core language     |
| PostgreSQL 16+     | Relational DB     |
| SQLAlchemy, asyncpg| ORM and async DB  |
| Pydantic           | Data validation   |
| PyJWT, passlib     | JWT Auth, Hashing |
| SendGrid API       | Email             |
| Cloudinary         | Media/images      |

### Infrastructure
- Neon PostgreSQL
- Cloudinary
- SendGrid
- Railway, Vercel
- GitHub Actions

---

## 🏗 Architecture

### System Diagram

CLIENTS (Flutter: Android/iOS/Web/Desktop)
│
HTTPS/WSS
│
┌──────────── BACKEND (FastAPI/Uvicorn) ────────┐
│ REST Endpoints (JWT/CORS) │ WebSocket (/ws) │
│ SQLAlchemy / asyncpg / Alembic / SendGrid │
└───────────────────────────────────────────────┘
│ │ │
Neon DB Cloudinary SendGrid

text
- End-to-end encrypted, minimal server trust.

### Data Flow Example
1. User types → Flutter encrypts → POST to FastAPI
2. FastAPI stores + pushes via WebSocket
3. Receiver device decrypts and displays

---

## 🔒 Security

- AES-256-GCM message encryption (client-side)
- bcrypt password hashing
- JWT Auth, refresh/expiry
- Zero-knowledge: server never sees plaintext
- Rate limiting, XSS, CSRF, CORS, TLS 1.3

---

## 📥 Installation

#### 1. Clone Repo

git clone https://github.com/yourusername/noctisapp.git
cd noctisapp

text

#### 2. Generate Security Keys

python3 scripts/generate_keys.py

text
Copy these for your `.env` files.


#### 3. Backend Setup

cd backend
python3 -m venv venv
source venv/bin/activate # or venv\Scripts\activate on Windows
pip install -r requirements.txt
cp .env.example .env

Edit .env with your DB/API/email/cloudinary keys
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

text

#### 4. Frontend Setup

cd frontend
flutter pub get
flutter packages pub run build_runner build
flutter run -d chrome # for web
flutter run -d android # for Android
flutter run -d ios # for iOS

text

---

## ⚙️ Configuration

### Example `.env` for backend
APP_NAME=NoctisApp
VERSION=1.0.0
DEBUG=True

DATABASE_URL=postgresql+asyncpg://user:pass@host/db?sslmode=require
JWT_SECRET_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ENCRYPTION_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SENDGRID_API_KEY=SG.xxxxxx
FROM_EMAIL=you@domain.com
CLOUDINARY_CLOUD_NAME=yourcloud
CLOUDINARY_API_KEY=xxxx
CLOUDINARY_API_SECRET=xxxx

...and optional settings (REDIS, TURN, etc.)
text

### API Constants (Frontend)
Edit `frontend/lib/core/constants/api_constants.dart`:
static const String baseUrl = 'http://localhost:8000'; // Dev
static const String wsUrl = 'ws://localhost:8000';
// static const String baseUrl = 'https://api.yourdomain.com'; // Prod
// static const String wsUrl = 'wss://api.yourdomain.com';

text

---

## ⚠️ Known Limitations

- Single chat partner only
- Media: backend ready, frontend testing
- No push notifications yet
- Desktop builds not configured
- Voice/call features WIP
- No automated tests yet

---

## 🗺 Roadmap

See the detailed roadmap in the original README (feature/version table).

---

## 📚 API Documentation

Interactive: [http://localhost:8000/docs](http://localhost:8000/docs)

**Examples:**

POST /api/v1/auth/register
{
"email": "user@example.com",
"password": "SecurePass123!",
"name": "John Doe"
}

text

More in FastAPI Swagger docs.

---

## 🧪 Testing

**Backend**  
cd backend
pytest

text

**Frontend**
cd frontend
flutter test

text

---

## 🤝 Contributing & License

- View/learn, but **no deployment, resale, or commercial use unless licensed.**
- See LICENSE.txt and section above for permitted/restricted use.
- For commercial rights: [harshithtc30@gmail.com](mailto:harshithtc30@gmail.com)

---

## 💬 Support

[appnoctis@gmail.com](mailto:appnoctis@gmail.com) • [Issues](https://github.com/yourusername/noctisapp/issues)

---

<div align="center">

**Built by Harshith TC**  
**© 2025 Harshith TC. All Rights Reserved.**

</div>