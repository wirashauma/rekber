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
└── frontend/                         # Flutter Mobile App
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

### Frontend Setup
1. Update Supabase credentials in `lib/core/constants/api_constants.dart`
2. Download [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans) fonts to `assets/fonts/`
3. Install dependencies:
   ```bash
   cd frontend
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
