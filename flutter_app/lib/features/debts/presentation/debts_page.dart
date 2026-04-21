import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/debts_api.dart";

final FutureProvider<List<Map<String, dynamic>>> debtsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(debtsApiProvider).getDebts();
});

class DebtsPage extends ConsumerWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> debts =
        ref.watch(debtsProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Hutang/Piutang",
      subtitle: "Pantau pinjaman masuk dan keluar",
      currentPath: "/debts",
      showBottomNavigation: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showDebtDialog(context, ref);
          if (changed) ref.invalidate(debtsProvider);
        },
        child: const Icon(Icons.add),
      ),
      child: debts.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada data hutang/piutang",
              subtitle:
                  "Kelola siapa yang perlu dibayar atau menunggak ke kamu.",
              icon: Icons.account_balance_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showDebtDialog(context, ref);
                  if (changed) ref.invalidate(debtsProvider);
                },
                child: const Text("Tambah Data"),
              ),
            );
          }
          num receivableTotal = 0;
          num debtTotal = 0;
          for (final Map<String, dynamic> item in data) {
            final bool isOwed = (item["direction"] ?? "owe").toString() == "owed";
            if (isOwed) {
              receivableTotal += (item["amount"] ?? 0) as num;
            } else {
              debtTotal += (item["amount"] ?? 0) as num;
            }
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(debtsProvider.future),
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
                            label: "Piutang",
                            value: currency.format(receivableTotal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryItem(
                            label: "Hutang",
                            value: currency.format(debtTotal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...data.map((Map<String, dynamic> item) {
                  final bool isOwed = (item["direction"] ?? "owe").toString() == "owed";
                  final bool paid = (item["status"] ?? "unpaid").toString() == "paid";
                  return Card(
                    child: ListTile(
                      title: Text((item["debtorName"] ?? "-").toString()),
                      subtitle: Text(
                        "${isOwed ? "Piutang" : "Hutang"} • ${(item["description"] ?? "").toString()}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                currency.format((item["amount"] ?? 0) as num),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(paid ? "Lunas" : "Belum lunas"),
                            ],
                          ),
                          IconButton(
                            onPressed: () async {
                              final bool changed = await _showDebtDialog(
                                context,
                                ref,
                                initial: item,
                              );
                              if (changed) ref.invalidate(debtsProvider);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              final bool confirm = await confirmDelete(context);
                              if (!confirm) return;
                              final int id = _parseInt(item["id"]) ?? 0;
                              if (id <= 0) return;
                              await ref.read(debtsApiProvider).deleteDebt(id);
                              ref.invalidate(debtsProvider);
                              if (context.mounted) {
                                showInfoSnackbar(context, "Data dihapus");
                              }
                            },
                            icon: const Icon(Icons.delete, size: 18),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final int id = _parseInt(item["id"]) ?? 0;
                        if (id <= 0) return;
                        await ref.read(debtsApiProvider).updateDebt(
                          id,
                          <String, dynamic>{"status": paid ? "unpaid" : "paid"},
                        );
                        ref.invalidate(debtsProvider);
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat hutang/piutang"),
          onRetry: () => ref.invalidate(debtsProvider),
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

Future<bool> _showDebtDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController debtorController = TextEditingController(
    text: (initial?["debtorName"] ?? "").toString(),
  );
  final TextEditingController amountController = TextEditingController(
    text: (initial?["amount"] ?? "").toString(),
  );
  final TextEditingController descController = TextEditingController(
    text: (initial?["description"] ?? "").toString(),
  );
  String direction = (initial?["direction"] ?? "owe").toString();
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null
                ? "Tambah Hutang/Piutang"
                : "Edit Hutang/Piutang"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: debtorController,
                    decoration: const InputDecoration(labelText: "Nama"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Deskripsi"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: direction,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                          value: "owe", child: Text("Saya berhutang")),
                      DropdownMenuItem(
                          value: "owed",
                          child: Text("Orang berhutang ke saya")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => direction = value);
                    },
                    decoration: const InputDecoration(labelText: "Arah"),
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
                        final double? amount =
                            double.tryParse(amountController.text);
                        if (debtorController.text.trim().isEmpty ||
                            amount == null ||
                            amount <= 0) {
                          setState(() => errorText = "Data tidak valid.");
                          return;
                        }

                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          final Map<String, dynamic> payload =
                              <String, dynamic>{
                            "debtorName": debtorController.text.trim(),
                            "amount": amount,
                            "description": descController.text.trim(),
                            "direction": direction,
                          };
                          if (initial == null) {
                            await ref
                                .read(debtsApiProvider)
                                .createDebt(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref
                                .read(debtsApiProvider)
                                .updateDebt(id, payload);
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan data.";
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

int? _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? "");
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
