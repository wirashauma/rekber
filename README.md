# REKBER — Automated Escrow Platform 🛡️

> Secure buyer-seller transactions with automated fund holding. Funds are protected in escrow until the buyer confirms receipt or a dispute is resolved.

## 🏗️ Architecture

```
rekber/
├── backend/                          # Supabase Backend
│   └── supabase/
│       ├── config.toml               # Supabase project config
│       ├── seed.sql                  # Development seed data
│       ├── migrations/
│       │   └── 001_initial_schema.sql  # Full DB schema + RLS + Functions
│       └── functions/                # Edge Functions (Deno/TypeScript)
│           ├── create-transaction/   # Create new escrow transaction
│           ├── process-payment/      # Mock payment gateway (Xendit/Midtrans)
│           ├── update-transaction-status/ # Escrow state machine handler
│           ├── process-withdrawal/   # Seller withdrawal processing
│           └── webhook-payment/      # Payment gateway callback
│
└── mobile/                           # Flutter Mobile App
    ├── lib/
    │   ├── main.dart                 # Entry point
    │   ├── app.dart                  # Root widget with BLoC providers
    │   ├── injection_container.dart  # GetIt DI setup
    │   ├── config/                   # Routes & Supabase config
    │   ├── core/                     # Design system, utilities, base classes
    │   │   ├── constants/            # Colors, typography, dimensions, API
    │   │   ├── theme/                # Material 3 theme
    │   │   ├── errors/               # Failures & exceptions
    │   │   ├── usecases/             # Base UseCase contract
    │   │   ├── utils/                # Currency & date formatters
    │   │   └── widgets/              # Reusable UI components
    │   └── features/                 # Feature modules (Clean Architecture)
    │       ├── auth/                 # Login, Register, KYC
    │       ├── home/                 # Role-switchable dashboard
    │       ├── transaction/          # Create, track, escrow state machine
    │       ├── chat/                 # Real-time transaction chat
    │       ├── wallet/               # Balance, withdrawal
    │       └── product/              # Seller catalog CRUD
    ├── assets/                       # Images, icons, fonts, animations
    ├── pubspec.yaml
    └── analysis_options.yaml
```

## 🛠️ Tech Stack

### Backend

| Category | Technology | Description |
|----------|-----------|-------------|
| **Runtime** | Node.js (≥ 18) | JavaScript runtime |
| **Framework** | Express v5 | HTTP server & REST API |
| **Language** | JavaScript (CommonJS) | Backend logic |
| **ORM** | Prisma v7 | Type-safe database access & migrations |
| **Database** | PostgreSQL | Primary relational database (via Supabase) |
| **BaaS** | Supabase | Hosted Postgres, Edge Functions, Auth, Realtime |
| **Edge Functions** | Deno / TypeScript | Serverless functions for escrow logic |
| **Auth** | JSON Web Token (jsonwebtoken) | API authentication & authorization |
| **Security** | Helmet | HTTP security headers |
| **Password Hashing** | bcryptjs | Secure password hashing |
| **Validation** | express-validator | Request input validation |
| **HTTP Logging** | Morgan | HTTP request logger middleware |
| **CORS** | cors | Cross-Origin Resource Sharing |
| **Env Config** | dotenv | Environment variable management |
| **DB Driver** | pg | PostgreSQL client for Node.js |
| **Dev Tools** | Nodemon | Auto-restart server on file changes |

### Mobile

| Category | Technology | Description |
|----------|-----------|-------------|
| **Framework** | Flutter (≥ 3.2.0) | Cross-platform UI framework |
| **Language** | Dart (≥ 3.2.0) | Mobile app language |
| **State Management** | flutter_bloc / bloc | BLoC pattern with event/state separation |
| **Dependency Injection** | get_it + injectable | Service locator & code generation DI |
| **Routing** | go_router | Declarative routing |
| **Backend Client** | supabase_flutter | Supabase SDK for Flutter |
| **Firebase** | firebase_core, firebase_auth, firebase_messaging | Auth, push notifications |
| **Notifications** | flutter_local_notifications | Local push notifications |
| **Functional Programming** | dartz | Either, Option, functional error handling |
| **Networking** | http | HTTP client |
| **UI/Design** | google_fonts, flutter_svg, shimmer, lottie | Typography, SVG, loading skeletons, animations |
| **Image Handling** | image_picker, image_cropper, cached_network_image | Pick, crop, and cache images |
| **Charts** | fl_chart | Seller dashboard analytics |
| **QR Code** | qr_flutter | QRIS payment QR generation |
| **Storage** | shared_preferences, flutter_secure_storage | Local & secure key-value storage |
| **Utilities** | intl, uuid, timeago, url_launcher, share_plus | i18n, unique IDs, time formatting, deep links, sharing |
| **Value Equality** | equatable | Simplified equality comparisons for BLoC states |
| **Testing** | flutter_test, integration_test, bloc_test, mocktail | Unit, integration, and BLoC testing |
| **Code Generation** | build_runner, injectable_generator | DI & boilerplate code generation |
| **Linting** | flutter_lints | Static analysis rules |

### Infrastructure & DevOps

| Category | Technology | Description |
|----------|-----------|-------------|
| **Database Hosting** | Supabase (PostgreSQL) | Managed cloud Postgres |
| **Serverless** | Supabase Edge Functions | Deno-based serverless compute |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Cross-platform push notifications |
| **Authentication** | Firebase Auth + JWT | Multi-provider auth |
| **Version Control** | Git | Source code management |

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.2.0
- Dart SDK >= 3.2.0
- Supabase CLI
- Node.js >= 18 (for Supabase functions)

### Backend Setup
1. Install [Supabase CLI](https://supabase.com/docs/guides/cli)
2. Create a new Supabase project
3. Run the migration:
   ```bash
   cd backend
   supabase db push
   ```
4. Deploy Edge Functions:
   ```bash
   supabase functions deploy create-transaction
   supabase functions deploy process-payment
   supabase functions deploy update-transaction-status
   supabase functions deploy process-withdrawal
   supabase functions deploy webhook-payment
   ```

### Mobile Setup
1. Update Supabase credentials in `lib/core/constants/api_constants.dart`
2. Download [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans) fonts to `assets/fonts/`
3. Install dependencies:
   ```bash
   cd mobile
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## 🎨 Design System
- **Primary:** Deep Emerald `#1B5E37`
- **Accent:** Gold `#D4A844` (for escrow/money)
- **Font:** Plus Jakarta Sans
- **Style:** Clean cards, rounded 16px, status-colored accents

## 📦 State Management
**BLoC** pattern with strict event/state separation and `flutter_bloc` package.

## 🔒 Escrow Flow
```
Awaiting Payment → Escrow (Paid) → Processed → Shipped → Completed
                                                    ↓
                                                 Disputed → Completed/Refunded
```

## 📄 License
Proprietary — All rights reserved.
