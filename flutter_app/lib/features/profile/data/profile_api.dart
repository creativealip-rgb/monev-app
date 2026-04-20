import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";

class ProfileApi {
  ProfileApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getProfile() async {
    final Response<dynamic> response = await _dio.get<dynamic>("/api/mobile/profile");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    await _dio.patch<dynamic>("/api/mobile/profile", data: payload);
  }
}

final Provider<ProfileApi> profileApiProvider = Provider<ProfileApi>(
  (Ref ref) => ProfileApi(ref.read(dioProvider)),
);

