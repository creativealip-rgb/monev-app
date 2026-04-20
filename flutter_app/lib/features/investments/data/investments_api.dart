import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class InvestmentsApi {
  InvestmentsApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getSummary() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/investments");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<void> createInvestment(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/investments", data: payload);
  }

  Future<void> updateInvestment(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/investments/$id", data: payload);
  }

  Future<void> deleteInvestment(int id) async {
    await _dio.delete<dynamic>("/api/mobile/investments/$id");
  }
}

final Provider<InvestmentsApi> investmentsApiProvider = Provider<InvestmentsApi>(
  (Ref ref) => InvestmentsApi(ref.read(dioProvider)),
);

