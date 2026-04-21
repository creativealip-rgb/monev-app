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
    final AsyncValue<Map<String, dynamic>> insight =
        ref.watch(aiInsightProvider);

    return MobileScaffold(
      title: "Insight AI",
      subtitle: "Rekomendasi cerdas untuk keuanganmu",
      currentPath: "/ai-insight",
      showBottomNavigation: false,
      child: insight.when(
        data: (Map<String, dynamic> data) {
          final String text =
              (data["insight"] ?? "Belum ada insight").toString();
          final String type = (data["type"] ?? "info").toString();
          final Color color = switch (type) {
            "success" => Colors.green,
            "warning" => Colors.orange,
            _ => const Color(0xFF1E56C7),
          };

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.lightbulb_outline_rounded,
                              color: color),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Insight Hari Ini",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      text,
                      style: const TextStyle(
                        height: 1.45,
                        color: Color(0xFF213A5E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(aiInsightProvider),
                      child: const Text("Muat Ulang Insight"),
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
