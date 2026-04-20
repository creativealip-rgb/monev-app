import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class ReportsApi {
  ReportsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getHistory() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/reports/history");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> exportCsv() async {
    final Response<String> response = await _dio.get<String>(
      "/api/mobile/reports/export",
      queryParameters: <String, dynamic>{"format": "csv"},
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? "";
  }
}

final Provider<ReportsApi> reportsApiProvider = Provider<ReportsApi>(
  (Ref ref) => ReportsApi(ref.read(dioProvider)),
);

