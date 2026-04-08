class ApiConstants {
  ApiConstants._();

  // Claude API
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';
  static const String claudeMessagesEndpoint = '/messages';
  static const String claudeModel = 'claude-sonnet-4-6';
  static const String anthropicVersion = '2023-06-01';
  static const int claudeMaxTokens = 4096;

  // YNAB API
  static const String ynabBaseUrl = 'https://api.ynab.com/v1';
  static const String ynabBudgetsEndpoint = '/budgets';

  // YNAB OAuth 2.0
  // Register your app at https://app.ynab.com/oauth/applications
  // Use redirect URI: com.receiptscan.ynab://oauth/callback
  static const String ynabClientId = 'YOUR_CLIENT_ID_HERE';
  static const String ynabRedirectUri = 'com.receiptscan.ynab://oauth/callback';
  static const String ynabAuthorizationEndpoint = 'https://app.ynab.com/oauth/authorize';
  static const String ynabTokenEndpoint = 'https://api.ynab.com/oauth/token';

  // Storage keys
  static const String keyYnabAccessToken = 'ynab_access_token';
  static const String keyYnabRefreshToken = 'ynab_refresh_token';
  static const String keyYnabTokenExpiresAt = 'ynab_token_expires_at'; // SharedPreferences, epoch seconds
  static const String keyAnthropicApiKey = 'anthropic_api_key';
  static const String keyDefaultBudgetId = 'default_budget_id';
  static const String keyDefaultAccountId = 'default_account_id';

  // Image compression
  static const int imageMaxDimension = 1600;
  static const int imageQuality = 90;
}
