import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:claimsupport/core/routing/app_router.dart';

class AuthInterceptor extends Interceptor {
  // Global lock for token refresh to prevent race conditions
  static Future<bool>? _refreshFuture;
  
  // Flag to prevent duplicate session expired dialogs
  static bool _sessionExpiredShown = false;

  // Flag to indicate intentional manual logout
  static bool isManualLogout = false;

  /// Resets the session expired flag. Should be called after successful login.
  static void resetSessionExpiredFlag() {
    _sessionExpiredShown = false;
    isManualLogout = false;
  }

  /// Parses the JWT token to extract the payload map.
  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Pad with '=' to make it a valid base64 string
      String normalized = base64Url.normalize(payload);
      String resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp);
    } catch (e) {
      return null;
    }
  }

  /// Checks if the token is expiring in less than 5 minutes.
  bool _isTokenExpiringSoon(String token) {
    final payload = _parseJwt(token);
    // If we can't parse it or it lacks exp, assume it needs refresh
    if (payload == null || !payload.containsKey('exp')) {
      return true; 
    }

    final exp = payload['exp'] as int;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    final now = DateTime.now().toUtc();

    // Check if expiring within 300 seconds (5 minutes)
    return expiryDate.difference(now).inSeconds < 300;
  }

  /// Clears session and shows a non-dismissible dialog before redirecting to login.
  Future<void> _logoutAndRedirectToLogin() async {
    // If it's an intentional manual logout, do not show the dialog and do not redirect 
    // (the profile screen will handle redirection).
    if (isManualLogout) return;

    // If a dialog was already shown, don't show another one.
    if (_sessionExpiredShown) return;
    _sessionExpiredShown = true;

    await AuthStorage.clearTokens();

    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Session Expired'),
          content: const Text('Your login session has expired. Please sign in again to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    
    // Clear routes and force navigate to login
    AppRouter.router.go('/login');
  }

  /// Performs the actual refresh call to the backend.
  Future<bool> _performRefresh(String baseUrl, String refreshToken) async {
    try {
      final freshDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await freshDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200) {
        final newToken = response.data['token'];
        final newRefreshToken = response.data['refreshToken'];

        if (newToken != null) {
          await AuthStorage.saveToken(newToken);
        }
        if (newRefreshToken != null) {
          await AuthStorage.saveRefreshToken(newRefreshToken);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Orchestrates the refresh logic ensuring only one network call happens at a time.
  Future<bool> _shouldRefreshToken(String baseUrl) async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null) return false;

    // Wait for the ongoing refresh to finish if one is already in progress
    if (_refreshFuture != null) {
      return await _refreshFuture!;
    }

    // Start a new refresh process
    try {
      _refreshFuture = _performRefresh(baseUrl, refreshToken);
      return await _refreshFuture!;
    } finally {
      // Always clear the lock so subsequent valid refreshes can happen
      _refreshFuture = null;
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      String? token = await AuthStorage.getToken();

      if (token != null) {
        // Proactively check if the token is about to expire
        if (_isTokenExpiringSoon(token)) {
          final success = await _shouldRefreshToken(options.baseUrl);
          if (success) {
            token = await AuthStorage.getToken(); // Fetch the newly saved token
          } else {
            // Refresh failed proactively. Abort request and logout.
            await _logoutAndRedirectToLogin();
            return handler.reject(DioException(
              requestOptions: options,
              error: 'Session expired. Please log in again.',
              type: DioExceptionType.cancel,
            ));
          }
        }
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If token retrieval fails, proceed without it (might be a public route)
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Safety net: if a 401 still happens (e.g. backend clock mismatch or revoked token)
    if (err.response?.statusCode == 401) {
      try {
        final success = await _shouldRefreshToken(err.requestOptions.baseUrl);

        if (success) {
          final newToken = await AuthStorage.getToken();

          // Retry the original request with the new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final opts = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          );

          // Create a fresh Dio instance to avoid interceptor loop for the retry
          final freshDio = Dio(BaseOptions(
            baseUrl: err.requestOptions.baseUrl,
          ));

          final retryResponse = await freshDio.request(
            err.requestOptions.path,
            options: opts,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );

          return handler.resolve(retryResponse);
        } else {
          // If refresh fails due to 401/403 (invalid refresh token), logout
          await _logoutAndRedirectToLogin();
        }
      } catch (_) {
        // Refresh failed catastrophically
        await _logoutAndRedirectToLogin();
      }
    }

    handler.next(err);
  }
}
