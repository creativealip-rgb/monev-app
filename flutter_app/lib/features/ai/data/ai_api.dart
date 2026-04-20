import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class AiApi {
  AiApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getInsight() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/ai/insight");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 50}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      "/api/mobile/ai/history",
      queryParameters: <String, dynamic>{"limit": limit},
    );
    final List<dynamic> data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendChat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      "/api/mobile/ai/chat",
      data: <String, dynamic>{
        "message": message,
        "history": history,
      },
    );
    return response.data["data"] as Map<String, dynamic>;
  }
}

final Provider<AiApi> aiApiProvider = Provider<AiApi>(
  (Ref ref) => AiApi(ref.read(dioProvider)),
);

