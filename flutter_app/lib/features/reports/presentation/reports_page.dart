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
      title: "Laporan",
      subtitle: "Riwayat export dan ringkasan data",
      currentPath: "/reports",
      showBottomNavigation: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      "Pusat Laporan",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2547),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Export laporan transaksi terbaru dalam format CSV untuk analisis lanjutan.",
                      style: TextStyle(color: Color(0xFF4F6D95)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _exporting
                          ? null
                          : () async {
                              setState(() => _exporting = true);
                              try {
                                final String csv = await ref
                                    .read(reportsApiProvider)
                                    .exportCsv();
                                if (!context.mounted) return;
                                showInfoSnackbar(context,
                                    "Export CSV siap (${csv.length} karakter)");
                              } on DioException catch (e) {
                                final dynamic body = e.response?.data;
                                if (!context.mounted) return;
                                showInfoSnackbar(
                                  context,
                                  body is Map<String, dynamic> &&
                                          body["error"] != null
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
                  ],
                ),
              ),
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
                  onRefresh: () async =>
                      ref.refresh(reportsHistoryProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> item = data[index];
                      return Card(
                        child: ListTile(
                          title: Text((item["type"] ?? "Laporan").toString()),
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
                message: _apiError(error, "Gagal memuat riwayat laporan"),
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
