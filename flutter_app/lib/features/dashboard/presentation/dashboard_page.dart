import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
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
          title: "Beranda",
          subtitle: "Ringkasan finansial hari ini",
          currentPath: "/dashboard",
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              _HeroCard(
                netWorth:
                    currency.format((totals["netWorthApprox"] ?? 0) as num),
                balance: currency.format((stats["balance"] ?? 0) as num),
              ),
              const SizedBox(height: 16),
              Text(
                "Ringkasan Bulan Ini",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F2547),
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      title: "Pemasukan",
                      value: currency.format((stats["income"] ?? 0) as num),
                      accent: const Color(0xFF12986B),
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: "Pengeluaran",
                      value: currency.format((stats["expense"] ?? 0) as num),
                      accent: const Color(0xFFC55044),
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Menu Utama",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F2547),
                    ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _QuickActionCard(
                        width: itemWidth,
                        label: "Transaksi",
                        icon: Icons.receipt_long_rounded,
                        onTap: () => context.go("/transactions"),
                      ),
                      _QuickActionCard(
                        width: itemWidth,
                        label: "Anggaran",
                        icon: Icons.pie_chart_rounded,
                        onTap: () => context.go("/budgets"),
                      ),
                      _QuickActionCard(
                        width: itemWidth,
                        label: "Target",
                        icon: Icons.flag_rounded,
                        onTap: () => context.go("/goals"),
                      ),
                      _QuickActionCard(
                        width: itemWidth,
                        label: "Laporan",
                        icon: Icons.insert_chart_outlined,
                        onTap: () => context.go("/reports"),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const MobileScaffold(
        title: "Beranda",
        subtitle: "Ringkasan finansial hari ini",
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
          title: "Beranda",
          subtitle: "Ringkasan finansial hari ini",
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.netWorth,
    required this.balance,
  });

  final String netWorth;
  final String balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF215CD1), Color(0xFF2A8FEF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "Total Kekayaan",
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              netWorth,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Saldo bulan ini $balance",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4C6B95),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2547),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final double width;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFEAFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E56C7), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3558),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
