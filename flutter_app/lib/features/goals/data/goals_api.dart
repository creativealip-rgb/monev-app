import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class GoalsApi {
  GoalsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> getGoals() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/goals");
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> createGoal(Map<String, dynamic> payload) async {
    await _dio.post<dynamic>("/api/mobile/goals", data: payload);
  }

  Future<void> updateGoal(int id, Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/goals/$id", data: payload);
  }

  Future<void> deleteGoal(int id) async {
    await _dio.delete<dynamic>("/api/mobile/goals/$id");
  }
}

final Provider<GoalsApi> goalsApiProvider = Provider<GoalsApi>(
  (Ref ref) => GoalsApi(ref.read(dioProvider)),
);

