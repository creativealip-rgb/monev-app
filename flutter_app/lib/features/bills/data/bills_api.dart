import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class BillsApi {
  BillsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getBills() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/bills");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createBill(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/bills", data: payload);
  }

  Future<void> updateBill(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/bills/$id", data: payload);
  }

  Future<void> deleteBill(int id) async {
    await _dio.delete<dynamic>("/api/mobile/bills/$id");
  }
}

final Provider<BillsApi> billsApiProvider = Provider<BillsApi>(
  (Ref ref) => BillsApi(ref.read(dioProvider)),
);

