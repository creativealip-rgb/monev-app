import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../data/auth_api.dart";

class StartupGatePage extends ConsumerStatefulWidget {
  const StartupGatePage({super.key});

  @override
  ConsumerState<StartupGatePage> createState() => _StartupGatePageState();
}

class _StartupGatePageState extends ConsumerState<StartupGatePage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_checkSession);
  }

  Future<void> _checkSession() async {
    final bool validSession = await ref.read(authApiProvider).hasValidSession();
    if (!mounted) return;
    context.go(validSession ? "/dashboard" : "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFCEE2FF), Color(0xFFF4F8FF)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1E56C7),
                size: 34,
              ),
              SizedBox(height: 12),
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 12),
              Text(
                "Menyiapkan Monev...",
                style: TextStyle(
                  color: Color(0xFF4F6D95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

