import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/reports_api.dart";

final FutureProvider<List<Map<String, dynamic>>> reportsHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(reportsApiProvider).getHistory();
});

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Map<String, dynamic>>> history = ref.watch(
      reportsHistoryProvider,
    );

    return MobileScaffold(
      title: "Reports",
      currentPath: "/dashboard",
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _exporting
                  ? null
                  : () async {
                      setState(() => _exporting = true);
                      try {
                        final String csv = await ref.read(reportsApiProvider).exportCsv();
                        if (!mounted) return;
                        showInfoSnackbar(context, "Export CSV siap (${csv.length} karakter)");
                      } on DioException catch (e) {
                        final dynamic body = e.response?.data;
                        if (!mounted) return;
                        showInfoSnackbar(
                          context,
                          body is Map<String, dynamic> && body["error"] != null
                              ? body["error"].toString()
                              : "Gagal export CSV",
                        );
                      } finally {
                        if (mounted) setState(() => _exporting = false);
                      }
                    },
              icon: const Icon(Icons.download_outlined),
              label: Text(_exporting ? "Memproses..." : "Export CSV"),
            ),
          ),
          Expanded(
            child: history.when(
              data: (List<Map<String, dynamic>> data) {
                if (data.isEmpty) {
                  return const AppEmptyView(
                    title: "Belum ada riwayat laporan",
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(reportsHistoryProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> item = data[index];
                      return Card(
                        child: ListTile(
                          title: Text((item["type"] ?? "Report").toString()),
                          subtitle: Text((item["period"] ?? "-").toString()),
                          trailing: Text((item["status"] ?? "-").toString()),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const AppLoadingView(),
              error: (Object error, StackTrace _) => AppErrorView(
                message: _apiError(error, "Gagal memuat report history"),
                onRetry: () => ref.invalidate(reportsHistoryProvider),
              ),
            ),
          ),
        ],
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

