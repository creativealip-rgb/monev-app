import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";
import "../../../core/storage/token_storage.dart";

class AuthApi {
  AuthApi({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      "/api/mobile/auth/login",
      data: <String, dynamic>{
        "email": email.trim(),
        "password": password,
      },
    );

    final dynamic data = response.data["data"];
    await _tokenStorage.saveTokens(
      accessToken: data["accessToken"] as String,
      refreshToken: data["refreshToken"] as String,
    );
  }

  Future<void> logout() async {
    final String? refreshToken = await _tokenStorage.getRefreshToken();
    try {
      await _dio.post<dynamic>(
        "/api/mobile/auth/logout",
        data: <String, dynamic>{"refreshToken": refreshToken},
      );
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  Future<void> logoutAllSessions() async {
    try {
      await _dio.post<dynamic>(
        "/api/mobile/auth/logout",
        data: <String, dynamic>{"allSessions": true},
      );
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  Future<bool> hasValidSession() async {
    final String? refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      await _dio.get<dynamic>("/api/mobile/profile");
      return true;
    } on DioException {
      return false;
    }
  }
}

final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (Ref ref) => AuthApi(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  ),
);

