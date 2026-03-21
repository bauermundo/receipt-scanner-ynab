# Receipt Scanner → YNAB

A Flutter mobile app (Android + iOS) that photographs receipts, extracts data using Claude AI, and creates transactions in YNAB.

## Features

- **Camera / Gallery** — take a photo or pick an existing image
- **Claude AI parsing** — sends the image to `claude-sonnet-4-6` and receives structured receipt data (merchant, date, total, line items, suggested category)
- **Editable review** — correct any extracted fields before submitting
- **YNAB integration** — maps receipt to YNAB account, payee, and category; creates the transaction via YNAB API

## Getting Started

### Prerequisites

- [Flutter 3.19+](https://flutter.dev/docs/get-started/install)
- A [YNAB account](https://app.ynab.com) with a **Personal Access Token** (Settings → Developer Settings)
- An [Anthropic API key](https://console.anthropic.com)

### Setup

```bash
git clone <this-repo>
cd Ynab-extension
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### First Run

1. Tap the **Settings** (⚙) icon in the top-right corner
2. Enter your **YNAB Personal Access Token**
3. Enter your **Anthropic API Key**
4. Tap **Save API Keys**
5. Select your **Default Budget** and **Default Account**

### Usage

1. Tap **Take Photo** or **Choose from Gallery**
2. Claude AI will analyse the receipt (takes ~3–8 seconds)
3. Review and correct the extracted data
4. Map the payee and category to your YNAB entries
5. Tap **Create YNAB Transaction** — done!

## Architecture

```
lib/
├── core/              # Constants, error types, theme
├── data/
│   ├── models/        # Dart data classes (receipt + YNAB)
│   ├── services/      # Claude API, YNAB API, secure storage
│   └── repositories/  # Business logic layer
├── presentation/
│   ├── providers/     # Riverpod state management
│   └── screens/       # Settings, Camera, Review, YNAB Mapping
└── router.dart
```

## Key Technical Notes

- **API keys** are stored on-device using `flutter_secure_storage` (AES-256 on Android, Keychain on iOS)
- **Receipt images** are compressed to <1 MB before sending to Claude (max 1200px, 80% JPEG quality)
- **YNAB amounts** are in milliunits: `$25.50 = -25500` (negative = outflow)
- **Claude JSON extraction** defensively strips markdown fences in case Claude wraps the response

## Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `image_picker` | Camera / gallery access |
| `flutter_image_compress` | Resize images before upload |
| `http` | API requests |
| `flutter_secure_storage` | Encrypted API key storage |
| `shared_preferences` | Non-sensitive settings |
| `intl` | Date formatting |
| `json_annotation` | JSON serialization |
