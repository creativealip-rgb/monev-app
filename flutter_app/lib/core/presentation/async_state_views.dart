import "package:flutter/material.dart";

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            "Memuat data...",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF4F6D95)),
          ),
        ],
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text("Coba lagi"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.title,
    this.subtitle,
    this.action,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 34, color: const Color(0xFF5A7BA9)),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF4F6D95)),
                  ),
                ],
                if (action != null) ...<Widget>[
                  const SizedBox(height: 14),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
