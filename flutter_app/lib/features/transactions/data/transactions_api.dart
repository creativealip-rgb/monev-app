import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class TransactionsApi {
  TransactionsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      "/api/mobile/transactions",
      queryParameters: <String, dynamic>{"limit": 50, "offset": 0},
    );
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final Response<dynamic> response =
        await _dio.get<dynamic>("/api/mobile/categories");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createTransaction(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/transactions", data: payload);
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/transactions/$id", data: payload);
  }

  Future<void> deleteTransaction(int id) async {
    await _dio.delete<dynamic>("/api/mobile/transactions/$id");
  }

  Future<Map<String, dynamic>> importTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      "/api/mobile/transactions/import",
      data: <String, dynamic>{"transactions": transactions},
    );
    return response.data["data"] as Map<String, dynamic>;
  }
}

final Provider<TransactionsApi> transactionsApiProvider = Provider<TransactionsApi>(
  (Ref ref) => TransactionsApi(ref.read(dioProvider)),
);

