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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

