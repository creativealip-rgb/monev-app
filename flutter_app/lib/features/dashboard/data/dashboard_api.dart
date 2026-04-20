import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class DashboardApi {
  DashboardApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getSummary({
    int? month,
    int? year,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      "/api/mobile/dashboard/summary",
      queryParameters: <String, dynamic>{
        if (month != null) "month": month,
        if (year != null) "year": year,
      },
    );
    return response.data["data"] as Map<String, dynamic>;
  }
}

final Provider<DashboardApi> dashboardApiProvider = Provider<DashboardApi>(
  (Ref ref) => DashboardApi(ref.read(dioProvider)),
);

