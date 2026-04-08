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

  // Storage keys
  static const String keyYnabToken = 'ynab_token';
  static const String keyAnthropicApiKey = 'anthropic_api_key';
  static const String keyDefaultBudgetId = 'default_budget_id';
  static const String keyDefaultAccountId = 'default_account_id';

  // Image compression
  static const int imageMaxDimension = 1600;
  static const int imageQuality = 90;
}
