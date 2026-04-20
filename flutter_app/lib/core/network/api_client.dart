import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../config/app_config.dart";
import "../storage/token_storage.dart";

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>(
  (Ref ref) => TokenStorage(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ),
);

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final TokenStorage tokenStorage = ref.read(tokenStorageProvider);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: <String, String>{"Content-Type": "application/json"},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        final String? accessToken = await tokenStorage.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $accessToken";
        }
        handler.next(options);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        final bool isUnauthorized = error.response?.statusCode == 401;
        final bool alreadyRetried = error.requestOptions.extra["retried"] == true;
        final bool isMobileAuthPath =
            error.requestOptions.path.contains("/api/mobile/auth/");

        if (!isUnauthorized || alreadyRetried || isMobileAuthPath) {
          handler.next(error);
          return;
        }

        try {
          final String? refreshToken = await tokenStorage.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            await tokenStorage.clearTokens();
            handler.next(error);
            return;
          }

          final Response<dynamic> refreshResponse = await dio.post<dynamic>(
            "/api/mobile/auth/refresh",
            data: <String, dynamic>{"refreshToken": refreshToken},
          );

          final dynamic data = refreshResponse.data["data"];
          final String newAccessToken = data["accessToken"] as String;
          final String newRefreshToken = data["refreshToken"] as String;
          await tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          final RequestOptions requestOptions = error.requestOptions;
          requestOptions.headers["Authorization"] = "Bearer $newAccessToken";
          requestOptions.extra["retried"] = true;

          final Response<dynamic> retry = await dio.fetch<dynamic>(requestOptions);
          handler.resolve(retry);
        } catch (refreshError, stackTrace) {
          debugPrint("Token refresh failed: $refreshError");
          debugPrintStack(stackTrace: stackTrace);
          await tokenStorage.clearTokens();
          if (refreshError is DioException) {
            handler.next(refreshError);
            return;
          }
          handler.next(error);
        }
      },
    ),
  );

  return dio;
});

