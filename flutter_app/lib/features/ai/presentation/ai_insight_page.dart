import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/ai_api.dart";

final FutureProvider<Map<String, dynamic>> aiInsightProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  return ref.read(aiApiProvider).getInsight();
});

class AiInsightPage extends ConsumerWidget {
  const AiInsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>> insight = ref.watch(aiInsightProvider);

    return MobileScaffold(
      title: "AI Insight",
      currentPath: "/dashboard",
      child: insight.when(
        data: (Map<String, dynamic> data) {
          final String text = (data["insight"] ?? "Belum ada insight").toString();
          final String type = (data["type"] ?? "info").toString();
          final Color color = switch (type) {
            "success" => Colors.green,
            "warning" => Colors.orange,
            _ => Colors.blue,
          };

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Insight Hari Ini",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(text),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(aiInsightProvider),
                      child: const Text("Refresh Insight"),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat AI insight"),
          onRetry: () => ref.invalidate(aiInsightProvider),
        ),
      ),
    );
  }
}

String _apiError(Object error, String fallback) {
  if (error is DioException) {
    final dynamic body = error.response?.data;
    if (body is Map<String, dynamic> && body["error"] != null) {
      return body["error"].toString();
    }
  }
  return fallback;
}

