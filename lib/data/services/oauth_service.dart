import 'package:flutter_appauth/flutter_appauth.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}

class OAuthService {
  const OAuthService();

  static const _appAuth = FlutterAppAuth();

  static const _serviceConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: ApiConstants.ynabAuthorizationEndpoint,
    tokenEndpoint: ApiConstants.ynabTokenEndpoint,
  );

  /// Opens YNAB login in a browser tab, handles PKCE, and returns tokens.
  Future<OAuthTokens> authorize() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          ApiConstants.ynabClientId,
          ApiConstants.ynabRedirectUri,
          serviceConfiguration: _serviceConfig,
          // YNAB doesn't use scopes, but AppAuth requires a non-empty list
          scopes: ['default'],
        ),
      );

      if (result == null || result.accessToken == null) {
        throw const YnabException(
            'Authorization was cancelled or failed.', 'No token in response');
      }

      return OAuthTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
        expiresAt: result.accessTokenExpirationDateTime ?? _defaultExpiry(),
      );
    } on YnabException {
      rethrow;
    } catch (e) {
      throw YnabException(
          'Could not connect to YNAB. Please try again.', e.toString());
    }
  }

  /// Uses a stored refresh token to obtain a new access token.
  Future<OAuthTokens> refresh(String refreshToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          ApiConstants.ynabClientId,
          ApiConstants.ynabRedirectUri,
          serviceConfiguration: _serviceConfig,
          refreshToken: refreshToken,
          scopes: ['default'],
        ),
      );

      if (result == null || result.accessToken == null) {
        throw const YnabException(
            'Session expired. Please reconnect YNAB.', 'No token in refresh response');
      }

      return OAuthTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? refreshToken,
        expiresAt: result.accessTokenExpirationDateTime ?? _defaultExpiry(),
      );
    } on YnabException {
      rethrow;
    } catch (e) {
      throw YnabException(
          'Session expired. Please reconnect YNAB.', e.toString());
    }
  }

  /// YNAB tokens expire after 2 hours; use that as a safe default.
  static DateTime _defaultExpiry() =>
      DateTime.now().add(const Duration(hours: 2));
}
