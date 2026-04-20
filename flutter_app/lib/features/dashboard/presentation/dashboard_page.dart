import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/dashboard_api.dart";

final FutureProvider<Map<String, dynamic>> dashboardSummaryProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  return ref.read(dashboardApiProvider).getSummary();
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>> summary = ref.watch(
      dashboardSummaryProvider,
    );

    return summary.when(
        data: (Map<String, dynamic> data) {
          final Map<String, dynamic> stats =
              (data["stats"] as Map<String, dynamic>? ?? <String, dynamic>{});
          final Map<String, dynamic> totals =
              (data["totals"] as Map<String, dynamic>? ?? <String, dynamic>{});
          final NumberFormat currency = NumberFormat.currency(
            locale: "id_ID",
            symbol: "Rp ",
            decimalDigits: 0,
          );

          return MobileScaffold(
            title: "Dashboard",
            currentPath: "/dashboard",
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _InfoTile(
                  title: "Pemasukan Bulan Ini",
                  value: currency.format((stats["income"] ?? 0) as num),
                ),
                _InfoTile(
                  title: "Pengeluaran Bulan Ini",
                  value: currency.format((stats["expense"] ?? 0) as num),
                ),
                _InfoTile(
                  title: "Saldo Bulan Ini",
                  value: currency.format((stats["balance"] ?? 0) as num),
                ),
                _InfoTile(
                  title: "Estimasi Net Worth",
                  value: currency.format((totals["netWorthApprox"] ?? 0) as num),
                ),
              ],
            ),
          );
        },
        loading: () => const MobileScaffold(
          title: "Dashboard",
          currentPath: "/dashboard",
          child: AppLoadingView(),
        ),
        error: (Object error, StackTrace _) {
          String message = "Gagal memuat dashboard";
          if (error is DioException) {
            final dynamic data = error.response?.data;
            if (data is Map<String, dynamic> && data["error"] is String) {
              message = data["error"] as String;
            }
          }
          return MobileScaffold(
            title: "Dashboard",
            currentPath: "/dashboard",
            child: AppErrorView(
              message: message,
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
            ),
          );
        },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

