import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../../auth/data/auth_api.dart";
import "../data/profile_api.dart";

final FutureProvider<Map<String, dynamic>> profileProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  return ref.read(profileApiProvider).getProfile();
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>> profile = ref.watch(profileProvider);

    return MobileScaffold(
      title: "Profil",
      currentPath: "/profile",
      showBottomNavigation: false,
      child: profile.when(
        data: (Map<String, dynamic> data) {
          final Map<String, dynamic> user =
              (data["user"] as Map<String, dynamic>? ?? <String, dynamic>{});
          final Map<String, dynamic> settings =
              (data["settings"] as Map<String, dynamic>? ??
                  <String, dynamic>{});
          final String email = (user["email"] ?? "-").toString();
          final String username = (user["username"] ?? "-").toString();
          final String tier = (user["tier"] ?? "starter").toString();
          final String firstName = (user["firstName"] ?? "").toString().trim();
          final String lastName = (user["lastName"] ?? "").toString().trim();
          final String fullName = <String>[firstName, lastName]
              .where((String part) => part.isNotEmpty)
              .join(" ");
          final String displayName = fullName.isNotEmpty
              ? fullName
              : (username != "-" ? username : email);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              _ProfileHeaderCard(
                displayName: displayName,
                email: email,
                username: username,
                tier: tier,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: "Akun",
                subtitle: "Identitas dan status langganan",
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                        icon: Icons.email_outlined,
                        label: "Email",
                        value: email),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: "Tier",
                      value: tier,
                    ),
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: "Username",
                      value: username,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: "Preferensi",
                subtitle: "Pengaturan personal aplikasi",
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.visibility_outlined,
                      label: "Sembunyikan saldo",
                      value: ((settings["hideBalance"] ?? false) == true)
                          ? "Aktif"
                          : "Nonaktif",
                    ),
                    _InfoRow(
                      icon: Icons.notifications_active_outlined,
                      label: "Notifikasi",
                      value:
                          ((settings["notificationsEnabled"] ?? true) == true)
                              ? "Aktif"
                              : "Nonaktif",
                    ),
                    _InfoRow(
                      icon: Icons.language_outlined,
                      label: "Bahasa laporan",
                      value: _reportLocaleLabel(
                        (settings["reportLocale"] ?? "auto").toString(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: "Kelola Keuangan",
                subtitle: "Akses cepat fitur utama",
                child: Column(
                  children: <Widget>[
                    _ActionTile(
                      label: "Kelola Tagihan",
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.go("/bills"),
                    ),
                    _ActionTile(
                      label: "Kelola Hutang/Piutang",
                      icon: Icons.account_balance_outlined,
                      onTap: () => context.go("/debts"),
                    ),
                    _ActionTile(
                      label: "Kelola Investasi",
                      icon: Icons.trending_up_outlined,
                      onTap: () => context.go("/investments"),
                    ),
                    _ActionTile(
                      label: "Kelola Transaksi Berkala",
                      icon: Icons.repeat_outlined,
                      onTap: () => context.go("/recurring"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: "Insight & Laporan",
                child: Column(
                  children: <Widget>[
                    _ActionTile(
                      label: "Laporan & Export",
                      icon: Icons.insert_chart_outlined,
                      onTap: () => context.go("/reports"),
                    ),
                    _ActionTile(
                      label: "Insight AI",
                      icon: Icons.lightbulb_outline,
                      onTap: () => context.go("/ai-insight"),
                    ),
                    _ActionTile(
                      label: "Asisten AI",
                      icon: Icons.chat_bubble_outline,
                      onTap: () => context.go("/ai-chat"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: "Keamanan Akun",
                child: Column(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () async {
                        final bool changed = await _showEditProfileDialog(
                          context,
                          ref,
                          user: user,
                          settings: settings,
                        );
                        if (changed) ref.invalidate(profileProvider);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit Profil & Pengaturan"),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext dialogContext) => AlertDialog(
                            title: const Text("Logout semua perangkat"),
                            content: const Text(
                              "Sesi login di semua perangkat akan diakhiri. Lanjutkan?",
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text("Batal"),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text("Lanjut"),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        await ref.read(authApiProvider).logoutAllSessions();
                        if (context.mounted) context.go("/login");
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.error),
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout Semua Perangkat"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat profil"),
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.email,
    required this.username,
    required this.tier,
  });

  final String displayName;
  final String email;
  final String username;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String initial = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : "U";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              colors.primaryContainer,
              colors.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(
                    initial,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _ProfileChip(
                  icon: Icons.verified_user_outlined,
                  label: "Tier ${tier.toUpperCase()}",
                ),
                _ProfileChip(
                  icon: Icons.alternate_email,
                  label: username == "-" ? "Tanpa username" : username,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _showEditProfileDialog(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, dynamic> user,
  required Map<String, dynamic> settings,
}) async {
  final TextEditingController firstNameController = TextEditingController(
    text: (user["firstName"] ?? "").toString(),
  );
  final TextEditingController lastNameController = TextEditingController(
    text: (user["lastName"] ?? "").toString(),
  );
  final TextEditingController usernameController = TextEditingController(
    text: (user["username"] ?? "").toString(),
  );
  final TextEditingController whatsappController = TextEditingController(
    text: (user["whatsappId"] ?? "").toString(),
  );
  bool hideBalance = (settings["hideBalance"] ?? false) == true;
  bool notificationsEnabled =
      (settings["notificationsEnabled"] ?? true) == true;
  String reportLocale = (settings["reportLocale"] ?? "auto").toString();
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text("Edit Profil"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: "Nama depan"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lastNameController,
                    decoration:
                        const InputDecoration(labelText: "Nama belakang"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "WhatsApp"),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: hideBalance,
                    onChanged: (bool value) =>
                        setState(() => hideBalance = value),
                    title: const Text("Sembunyikan saldo"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: notificationsEnabled,
                    onChanged: (bool value) =>
                        setState(() => notificationsEnabled = value),
                    title: const Text("Notifikasi aktif"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: reportLocale,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: "auto", child: Text("Otomatis")),
                      DropdownMenuItem(value: "id", child: Text("Indonesia")),
                      DropdownMenuItem(value: "en", child: Text("English")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => reportLocale = value);
                    },
                    decoration:
                        const InputDecoration(labelText: "Bahasa laporan"),
                  ),
                  if (errorText != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text("Batal"),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          await ref
                              .read(profileApiProvider)
                              .updateProfile(<String, dynamic>{
                            "firstName": firstNameController.text.trim(),
                            "lastName": lastNameController.text.trim(),
                            "username": usernameController.text.trim(),
                            "whatsappId": whatsappController.text.trim(),
                            "hideBalance": hideBalance,
                            "notificationsEnabled": notificationsEnabled,
                            "reportLocale": reportLocale,
                          });

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                          if (context.mounted) {
                            showInfoSnackbar(
                                context, "Profil berhasil diperbarui");
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan profil.";
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: Text(isSaving ? "Menyimpan..." : "Simpan"),
              ),
            ],
          );
        },
      );
    },
  );

  return result == true;
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

String _reportLocaleLabel(String value) {
  switch (value) {
    case "id":
      return "Indonesia";
    case "en":
      return "English";
    default:
      return "Otomatis";
  }
}
