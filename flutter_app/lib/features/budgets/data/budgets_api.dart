import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class BudgetsApi {
  BudgetsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final DateTime now = DateTime.now();
    final Response<dynamic> response = await _dio.get<dynamic>(
      "/api/mobile/budgets",
      queryParameters: <String, dynamic>{"month": now.month, "year": now.year},
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

  Future<void> createBudget(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/budgets", data: payload);
  }

  Future<void> updateBudget(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/budgets/$id", data: payload);
  }

  Future<void> deleteBudget(int id) async {
    await _dio.delete<dynamic>("/api/mobile/budgets/$id");
  }
}

final Provider<BudgetsApi> budgetsApiProvider = Provider<BudgetsApi>(
  (Ref ref) => BudgetsApi(ref.read(dioProvider)),
);

