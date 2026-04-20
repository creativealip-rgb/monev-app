import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/auth/data/auth_api.dart";

class MobileScaffold extends ConsumerWidget {
  const MobileScaffold({
    required this.title,
    required this.currentPath,
    required this.child,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final String currentPath;
  final Widget child;
  final Widget? floatingActionButton;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(path: "/dashboard", label: "Dashboard", icon: Icons.home_outlined),
    _NavItem(
      path: "/transactions",
      label: "Transaksi",
      icon: Icons.receipt_long_outlined,
    ),
    _NavItem(path: "/budgets", label: "Budget", icon: Icons.pie_chart_outline),
    _NavItem(path: "/goals", label: "Goals", icon: Icons.flag_outlined),
    _NavItem(path: "/accounts", label: "Akun", icon: Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selectedIndex = _items.indexWhere(
      (_NavItem item) => item.path == currentPath,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              context.go("/profile");
            },
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () async {
              await ref.read(authApiProvider).logout();
              if (context.mounted) context.go("/login");
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onTap: (int index) {
          context.go(_items[index].path);
        },
        items: _items
            .map(
              (_NavItem item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

