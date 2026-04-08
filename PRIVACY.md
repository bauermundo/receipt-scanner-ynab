# Privacy Policy

**You Need A Receipt** ("the App") is an open-source mobile application that scans receipts and creates transactions in YNAB (You Need A Budget).

**Last updated:** April 8, 2026

## Data Collection

The App does **not** collect, store, or transmit any personal data to the developer or any third-party analytics service. There are no ads, tracking pixels, or telemetry of any kind.

## Data Storage

All credentials and settings are stored **locally on your device** using encrypted storage (Android Keystore / iOS Keychain):

- **YNAB OAuth tokens** — used to authenticate with the YNAB API
- **Anthropic API key** — used to send receipt images to Claude AI for processing
- **Budget and account preferences** — your selected defaults

No data is stored on any external server controlled by the developer.

## Third-Party Services

The App communicates directly with two third-party services:

### Anthropic (Claude AI)
- **What is sent:** Receipt images (camera photos or gallery picks) and a text prompt
- **Purpose:** Extract merchant name, date, items, totals, and match budget categories
- **Privacy policy:** https://www.anthropic.com/privacy

### YNAB (You Need A Budget)
- **What is sent:** Transaction details (date, amount, payee, category, memo)
- **Purpose:** Create transactions in your YNAB budget
- **Authentication:** OAuth 2.0 with PKCE — no passwords are stored by the App
- **Privacy policy:** https://www.ynab.com/privacy-policy

## Data Sharing

The App does **not** share your data with anyone. All communication occurs directly between your device and the two services listed above.

## Data Deletion

Uninstalling the App removes all locally stored data. You can also disconnect your YNAB account and clear your API key from the Settings screen at any time. To revoke the App's access to your YNAB account, visit your [YNAB Developer Settings](https://app.ynab.com/settings/developer).

## Children's Privacy

The App is not directed at children under 13 and does not knowingly collect data from children.

## Changes

Updates to this policy will be posted to this page. The "Last updated" date at the top will be revised accordingly.

## Contact

For questions about this privacy policy, please open an issue at https://github.com/bauermundo/receipt-scanner-ynab/issues.
