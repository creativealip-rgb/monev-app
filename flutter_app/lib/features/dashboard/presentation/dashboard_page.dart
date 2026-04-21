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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _HeroCard(
                netWorth:
                    currency.format((totals["netWorthApprox"] ?? 0) as num),
                balance: currency.format((stats["balance"] ?? 0) as num),
                income: currency.format((stats["income"] ?? 0) as num),
                expense: currency.format((stats["expense"] ?? 0) as num),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      title: "Transaksi",
                      value: ((stats["transactionCount"] ?? 0) as num).toString(),
                      accent: const Color(0xFF1E56C7),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: "Sisa Budget",
                      value: currency.format((stats["budgetRemaining"] ?? 0) as num),
                      accent: const Color(0xFF12986B),
                      icon: Icons.pie_chart_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: "Akun Aktif",
                      value: ((stats["activeAccounts"] ?? 0) as num).toString(),
                      accent: const Color(0xFFC55044),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: "Fitur Andalan",
                actionLabel: "",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemWidth = (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Monev AI",
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFFAB68FF),
                        onTap: () => context.go("/ai-chat"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Analisis",
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF6DD7FF),
                        onTap: () => context.go("/reports"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Anggaran",
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFFFFA84F),
                        onTap: () => context.go("/budgets"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Target",
                        icon: Icons.flag_rounded,
                        color: const Color(0xFF4FD99F),
                        onTap: () => context.go("/goals"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Tagihan",
                        icon: Icons.receipt_rounded,
                        color: const Color(0xFFFF6B6B),
                        onTap: () => context.go("/bills"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Utang",
                        icon: Icons.handshake_rounded,
                        color: const Color(0xFF4ECDC4),
                        onTap: () => context.go("/debts"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Investasi",
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFFFFD93D),
                        onTap: () => context.go("/investments"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Rekurring",
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFF95E1D3),
                        onTap: () => context.go("/recurring"),
                      ),
                      _FeatureIcon(
                        width: itemWidth,
                        label: "Tabungan",
                        icon: Icons.savings_rounded,
                        color: const Color(0xFFE4B5F7),
                        onTap: () => context.go("/accounts"),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: "Ringkasan Hari Ini",
                actionLabel: "Lihat Semua",
                onTap: () => context.go("/transactions"),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      label: "Pemasukan",
                      value: currency.format((stats["income"] ?? 0) as num),
                      color: const Color(0xFF12986B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: "Pengeluaran",
                      value: currency.format((stats["expense"] ?? 0) as num),
                      color: const Color(0xFFC55044),
                    ),
                  ),
                ],
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
    required this.income,
    required this.expense,
  });

  final String netWorth;
  final String balance;
  final String income;
  final String expense;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  "Total Kekayaan",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.trending_up_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            "+2.05%",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              netWorth,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Saldo bulan $balance",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.south_west_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Pemasukan",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          income,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.north_east_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Pengeluaran",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expense,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4C6B95),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F2547),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F2547),
          ),
        ),
        if (actionLabel.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E56C7),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.width,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final double width;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F2547),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4C6B95),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F2547),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

