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
    this.showBottomNavigation = true,
    this.subtitle,
    super.key,
  });

  final String title;
  final String currentPath;
  final Widget child;
  final Widget? floatingActionButton;
  final bool showBottomNavigation;
  final String? subtitle;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      path: "/dashboard",
      label: "Beranda",
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      path: "/transactions",
      label: "Transaksi",
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _NavItem(
      path: "/budgets",
      label: "Anggaran",
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart_rounded,
    ),
    _NavItem(
      path: "/goals",
      label: "Target",
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag_rounded,
    ),
    _NavItem(
      path: "/accounts",
      label: "Akun",
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selectedIndex = _items.indexWhere(
      (_NavItem item) => item.path == currentPath,
    );

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      extendBody: showBottomNavigation,
      appBar: AppBar(
        title: subtitle == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF476284),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              context.go("/profile");
            },
            icon: const Icon(Icons.person_outline),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (String value) async {
              if (value == "logout") {
                await ref.read(authApiProvider).logout();
                if (context.mounted) context.go("/login");
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: "logout",
                child: Text("Logout"),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFDCEBFF),
              Color(0xFFF3F8FF),
              Color(0xFFF8FBFF)
            ],
            stops: <double>[0, 0.22, 1],
          ),
        ),
        child: child,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNavigation
          ? NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) =>
                  context.go(_items[index].path),
              destinations: _items
                  .map(
                    (_NavItem item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            )
          : null,
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
