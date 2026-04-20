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
      title: "Profile",
      currentPath: "/dashboard",
      child: profile.when(
        data: (Map<String, dynamic> data) {
          final Map<String, dynamic> user =
              (data["user"] as Map<String, dynamic>? ?? <String, dynamic>{});
          final Map<String, dynamic> settings =
              (data["settings"] as Map<String, dynamic>? ?? <String, dynamic>{});

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _InfoCard(
                title: "Akun",
                children: <Widget>[
                  _InfoRow(label: "Email", value: (user["email"] ?? "-").toString()),
                  _InfoRow(label: "Tier", value: (user["tier"] ?? "starter").toString()),
                  _InfoRow(
                    label: "Username",
                    value: (user["username"] ?? "-").toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: "Pengaturan",
                children: <Widget>[
                  _InfoRow(
                    label: "Sembunyikan saldo",
                    value: ((settings["hideBalance"] ?? false) == true) ? "Ya" : "Tidak",
                  ),
                  _InfoRow(
                    label: "Notifikasi",
                    value: ((settings["notificationsEnabled"] ?? true) == true)
                        ? "Aktif"
                        : "Nonaktif",
                  ),
                  _InfoRow(
                    label: "Report locale",
                    value: (settings["reportLocale"] ?? "auto").toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                icon: const Icon(Icons.edit),
                label: const Text("Edit Profile & Settings"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/bills"),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text("Kelola Tagihan"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/debts"),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text("Kelola Hutang/Piutang"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/investments"),
                icon: const Icon(Icons.trending_up_outlined),
                label: const Text("Kelola Investasi"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/recurring"),
                icon: const Icon(Icons.repeat_outlined),
                label: const Text("Kelola Recurring"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/reports"),
                icon: const Icon(Icons.insert_chart_outlined),
                label: const Text("Laporan & Export"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/ai-insight"),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text("AI Insight"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go("/ai-chat"),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("AI Chat"),
              ),
              const SizedBox(height: 8),
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
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text("Batal"),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text("Lanjut"),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  await ref.read(authApiProvider).logoutAllSessions();
                  if (context.mounted) context.go("/login");
                },
                icon: const Icon(Icons.logout),
                label: const Text("Logout Semua Perangkat"),
              ),
            ],
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat profile"),
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
  bool notificationsEnabled = (settings["notificationsEnabled"] ?? true) == true;
  String reportLocale = (settings["reportLocale"] ?? "auto").toString();
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text("Edit Profile"),
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
                    decoration: const InputDecoration(labelText: "Nama belakang"),
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
                    onChanged: (bool value) => setState(() => hideBalance = value),
                    title: const Text("Sembunyikan saldo"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: notificationsEnabled,
                    onChanged: (bool value) => setState(() => notificationsEnabled = value),
                    title: const Text("Notifikasi aktif"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  DropdownButtonFormField<String>(
                    value: reportLocale,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: "auto", child: Text("Auto")),
                      DropdownMenuItem(value: "id", child: Text("Indonesia")),
                      DropdownMenuItem(value: "en", child: Text("English")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => reportLocale = value);
                    },
                    decoration: const InputDecoration(labelText: "Report locale"),
                  ),
                  if (errorText != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
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
                          await ref.read(profileApiProvider).updateProfile(<String, dynamic>{
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
                            showInfoSnackbar(context, "Profile berhasil diperbarui");
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> && body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan profile.";
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

