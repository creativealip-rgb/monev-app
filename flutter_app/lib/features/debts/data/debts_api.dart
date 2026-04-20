import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class DebtsApi {
  DebtsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getDebts() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/debts");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createDebt(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/debts", data: payload);
  }

  Future<void> updateDebt(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/debts/$id", data: payload);
  }

  Future<void> deleteDebt(int id) async {
    await _dio.delete<dynamic>("/api/mobile/debts/$id");
  }
}

final Provider<DebtsApi> debtsApiProvider = Provider<DebtsApi>(
  (Ref ref) => DebtsApi(ref.read(dioProvider)),
);

