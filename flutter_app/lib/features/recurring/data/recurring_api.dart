import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class RecurringApi {
  RecurringApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getRecurring() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/recurring");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createRecurring(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/recurring", data: payload);
  }

  Future<void> updateRecurring(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/recurring/$id", data: payload);
  }

  Future<void> deleteRecurring(int id) async {
    await _dio.delete<dynamic>("/api/mobile/recurring/$id");
  }
}

final Provider<RecurringApi> recurringApiProvider = Provider<RecurringApi>(
  (Ref ref) => RecurringApi(ref.read(dioProvider)),
);

