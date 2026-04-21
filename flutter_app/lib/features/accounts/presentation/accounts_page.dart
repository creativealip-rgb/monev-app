import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/accounts_api.dart";

final FutureProvider<List<Map<String, dynamic>>> accountsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(accountsApiProvider).getAccounts();
});

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> items =
        ref.watch(accountsProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Akun",
      subtitle: "Saldo semua dompet dan rekening",
      currentPath: "/accounts",
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showAccountDialog(context, ref);
          if (changed) ref.invalidate(accountsProvider);
        },
        child: const Icon(Icons.add),
      ),
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada akun",
              subtitle: "Tambahkan rekening bank, e-money, atau kas harian.",
              icon: Icons.account_balance_wallet_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showAccountDialog(context, ref);
                  if (changed) ref.invalidate(accountsProvider);
                },
                child: const Text("Tambah Akun"),
              ),
            );
          }
          final num totalBalance = data.fold<num>(
            0,
            (num sum, Map<String, dynamic> account) =>
                sum + ((account["balance"] ?? 0) as num),
          );
          final int activeCount = data.where(
            (Map<String, dynamic> account) => (account["isActive"] ?? true) == true,
          ).length;

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(accountsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _SummaryItem(
                            label: "Total Saldo",
                            value: currency.format(totalBalance),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryItem(
                            label: "Akun Aktif",
                            value: "$activeCount/${data.length}",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...data.map((Map<String, dynamic> account) {
                  final String type = (account["type"] ?? "").toString();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFDCE8FF),
                        child: Icon(
                          switch (type) {
                            "bank" => Icons.account_balance_rounded,
                            "emoney" => Icons.phone_iphone_rounded,
                            "cash" => Icons.payments_rounded,
                            "credit_card" => Icons.credit_card_rounded,
                            _ => Icons.account_balance_wallet_rounded,
                          },
                          color: const Color(0xFF1E56C7),
                        ),
                      ),
                      title: Text((account["name"] ?? "-").toString()),
                      subtitle: Text((account["type"] ?? "-").toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            currency.format((account["balance"] ?? 0) as num),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              final bool changed = await _showAccountDialog(
                                context,
                                ref,
                                initial: account,
                              );
                              if (changed) ref.invalidate(accountsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () async {
                              final bool confirm = await confirmDelete(context);
                              if (!confirm) return;
                              final int id = _parseInt(account["id"]) ?? 0;
                              if (id <= 0) return;
                              await ref
                                  .read(accountsApiProvider)
                                  .deleteAccount(id);
                              ref.invalidate(accountsProvider);
                              if (context.mounted) {
                                showInfoSnackbar(context, "Akun dihapus");
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat akun"),
          onRetry: () => ref.invalidate(accountsProvider),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E6B94),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3558),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _showAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController nameController = TextEditingController(
    text: initial == null ? "" : (initial["name"] ?? "").toString(),
  );
  final TextEditingController balanceController = TextEditingController(
    text: initial == null ? "0" : (initial["balance"] ?? 0).toString(),
  );
  String type = (initial?["type"] ?? "bank").toString();
  bool isActive = (initial?["isActive"] ?? true) == true;
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Akun" : "Edit Akun"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nama akun"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Saldo"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: "bank", child: Text("Bank")),
                      DropdownMenuItem(value: "emoney", child: Text("E-Money")),
                      DropdownMenuItem(value: "cash", child: Text("Cash")),
                      DropdownMenuItem(
                          value: "credit_card", child: Text("Credit Card")),
                      DropdownMenuItem(
                        value: "investment_wallet",
                        child: Text("Investment Wallet"),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => type = value);
                    },
                    decoration: const InputDecoration(labelText: "Tipe"),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (bool value) => setState(() => isActive = value),
                    title: const Text("Akun aktif"),
                    contentPadding: EdgeInsets.zero,
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
                        final double? balance =
                            double.tryParse(balanceController.text);
                        if (nameController.text.trim().isEmpty ||
                            balance == null ||
                            balance < 0) {
                          setState(() => errorText = "Data akun tidak valid.");
                          return;
                        }

                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          final Map<String, dynamic> payload =
                              <String, dynamic>{
                            "name": nameController.text.trim(),
                            "balance": balance,
                            "type": type,
                            "isActive": isActive,
                          };
                          if (initial == null) {
                            await ref
                                .read(accountsApiProvider)
                                .createAccount(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref.read(accountsApiProvider).updateAccount(
                                  id,
                                  payload,
                                );
                          }

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                          if (context.mounted) {
                            showInfoSnackbar(
                              context,
                              initial == null
                                  ? "Akun berhasil ditambahkan"
                                  : "Akun berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan akun.";
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

int? _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? "");
}
