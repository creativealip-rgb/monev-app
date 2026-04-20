import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "core/theme/app_theme.dart";
import "features/accounts/presentation/accounts_page.dart";
import "features/ai/presentation/ai_chat_page.dart";
import "features/ai/presentation/ai_insight_page.dart";
import "features/auth/presentation/login_page.dart";
import "features/auth/presentation/startup_gate_page.dart";
import "features/bills/presentation/bills_page.dart";
import "features/budgets/presentation/budgets_page.dart";
import "features/dashboard/presentation/dashboard_page.dart";
import "features/goals/presentation/goals_page.dart";
import "features/investments/presentation/investments_page.dart";
import "features/profile/presentation/profile_page.dart";
import "features/recurring/presentation/recurring_page.dart";
import "features/reports/presentation/reports_page.dart";
import "features/debts/presentation/debts_page.dart";
import "features/transactions/presentation/transactions_page.dart";

void main() {
  runApp(const ProviderScope(child: MonevApp()));
}

final _router = GoRouter(
  initialLocation: "/startup",
  routes: <RouteBase>[
    GoRoute(
      path: "/startup",
      builder: (BuildContext context, GoRouterState state) =>
          const StartupGatePage(),
    ),
    GoRoute(
      path: "/login",
      builder: (BuildContext context, GoRouterState state) => const LoginPage(),
    ),
    GoRoute(
      path: "/dashboard",
      builder: (BuildContext context, GoRouterState state) =>
          const DashboardPage(),
    ),
    GoRoute(
      path: "/transactions",
      builder: (BuildContext context, GoRouterState state) =>
          const TransactionsPage(),
    ),
    GoRoute(
      path: "/budgets",
      builder: (BuildContext context, GoRouterState state) => const BudgetsPage(),
    ),
    GoRoute(
      path: "/goals",
      builder: (BuildContext context, GoRouterState state) => const GoalsPage(),
    ),
    GoRoute(
      path: "/accounts",
      builder: (BuildContext context, GoRouterState state) => const AccountsPage(),
    ),
    GoRoute(
      path: "/profile",
      builder: (BuildContext context, GoRouterState state) => const ProfilePage(),
    ),
    GoRoute(
      path: "/bills",
      builder: (BuildContext context, GoRouterState state) => const BillsPage(),
    ),
    GoRoute(
      path: "/debts",
      builder: (BuildContext context, GoRouterState state) => const DebtsPage(),
    ),
    GoRoute(
      path: "/investments",
      builder: (BuildContext context, GoRouterState state) => const InvestmentsPage(),
    ),
    GoRoute(
      path: "/recurring",
      builder: (BuildContext context, GoRouterState state) => const RecurringPage(),
    ),
    GoRoute(
      path: "/reports",
      builder: (BuildContext context, GoRouterState state) => const ReportsPage(),
    ),
    GoRoute(
      path: "/ai-insight",
      builder: (BuildContext context, GoRouterState state) => const AiInsightPage(),
    ),
    GoRoute(
      path: "/ai-chat",
      builder: (BuildContext context, GoRouterState state) => const AiChatPage(),
    ),
  ],
);

class MonevApp extends StatelessWidget {
  const MonevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "Monev",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

