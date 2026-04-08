# Receipt Scanner for YNAB

A Flutter mobile app that scans receipts using Claude AI and creates categorized transactions in [YNAB](https://www.ynab.com/) (You Need A Budget).

## Features

- **AI-Powered Receipt Scanning** — Take a photo or pick from gallery; Claude AI extracts merchant, date, items, and totals
- **Smart Category Matching** — Claude matches each item to your actual YNAB budget categories
- **Split Transactions** — Multi-item receipts with different categories are automatically split
- **Account Auto-Detection** — Detects the payment card from the receipt and matches it to your YNAB account
- **AI-Generated Memo** — Summarizes purchased items into the transaction memo
- **OAuth 2.0** — Secure YNAB authentication via OAuth + PKCE (no personal access tokens)

## How It Works

1. **Scan** — Take a photo of your receipt
2. **Review** — Verify the extracted merchant, date, and total
3. **Confirm** — Check the matched categories and account, override if needed
4. **Import** — Transaction is created in YNAB with proper categorization

## Setup

### Prerequisites

- Flutter SDK 3.19+
- An [Anthropic API key](https://console.anthropic.com/) for Claude AI
- A [YNAB](https://www.ynab.com/) account

### YNAB OAuth App Registration

1. Go to [YNAB Developer Settings](https://app.ynab.com/settings/developer)
2. Click **New Application**
3. Set:
   - **Application Name**: Receipt Scanner
   - **Redirect URI**: `com.receiptscan.ynab://oauth/callback`
4. Copy the **Client ID**
5. Open `lib/core/constants/api_constants.dart` and replace `YOUR_CLIENT_ID_HERE` with your Client ID

### Build & Run

```bash
git clone <this-repo>
cd receipt-scanner-ynab
flutter pub get
flutter run
```

### First Launch

1. Open **Settings** (gear icon)
2. Tap **Connect YNAB Account** — authorizes via your browser
3. Enter your **Anthropic API Key**
4. Select your default **Budget** and **Account**
5. Start scanning receipts!

## Architecture

```
lib/
├── core/              # Constants, error types, theme
├── data/
│   ├── models/        # Dart data classes (receipt + YNAB)
│   ├── services/      # Claude API, YNAB API, OAuth, secure storage
│   └── repositories/  # Business logic layer
├── presentation/
│   ├── providers/     # Riverpod state management
│   └── screens/       # Camera, Review, YNAB Mapping, Settings
└── router.dart
```

## Privacy

- All API keys are stored locally on your device using encrypted storage
- Receipt images are sent directly to the Anthropic API — no intermediary server
- YNAB authentication uses OAuth 2.0 + PKCE — no passwords are stored
- No data is collected or transmitted beyond Anthropic and YNAB APIs

## License

MIT
