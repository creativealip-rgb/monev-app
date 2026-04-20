import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class AccountsApi {
  AccountsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final Response<dynamic> response =
        await _dio.get<dynamic>("/api/mobile/accounts");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createAccount(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/accounts", data: payload);
  }

  Future<void> updateAccount(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/accounts/$id", data: payload);
  }

  Future<void> deleteAccount(int id) async {
    await _dio.delete<dynamic>("/api/mobile/accounts/$id");
  }
}

final Provider<AccountsApi> accountsApiProvider = Provider<AccountsApi>(
  (Ref ref) => AccountsApi(ref.read(dioProvider)),
);

