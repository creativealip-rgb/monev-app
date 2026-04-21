import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/bills_api.dart";

final FutureProvider<List<Map<String, dynamic>>> billsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(billsApiProvider).getBills();
});

class BillsPage extends ConsumerWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> bills =
        ref.watch(billsProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Tagihan",
      subtitle: "Jadwal pembayaran rutin",
      currentPath: "/bills",
      showBottomNavigation: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showBillDialog(context, ref);
          if (changed) ref.invalidate(billsProvider);
        },
        child: const Icon(Icons.add),
      ),
      child: bills.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada tagihan",
              subtitle: "Tambah tagihan rutin kamu agar tidak terlewat.",
              icon: Icons.receipt_long_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showBillDialog(context, ref);
                  if (changed) ref.invalidate(billsProvider);
                },
                child: const Text("Tambah Tagihan"),
              ),
            );
          }
          final int unpaidCount = data.where(
            (Map<String, dynamic> bill) => (bill["isPaid"] ?? false) != true,
          ).length;
          final num unpaidTotal = data.fold<num>(
            0,
            (num sum, Map<String, dynamic> bill) => (bill["isPaid"] ?? false) == true
                ? sum
                : sum + ((bill["amount"] ?? 0) as num),
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(billsProvider.future),
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
                            label: "Belum Lunas",
                            value: "$unpaidCount tagihan",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryItem(
                            label: "Nominal Tertunda",
                            value: currency.format(unpaidTotal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...data.map((Map<String, dynamic> bill) {
                  final bool isPaid = (bill["isPaid"] ?? false) == true;
                  return Card(
                    child: ListTile(
                      title: Text((bill["name"] ?? "-").toString()),
                      subtitle: Text(
                        "Jatuh tempo tgl ${(bill["dueDate"] ?? "-").toString()} • ${(bill["frequency"] ?? "monthly").toString()}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                currency.format((bill["amount"] ?? 0) as num),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(isPaid ? "Lunas" : "Belum lunas"),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              final bool changed = await _showBillDialog(
                                context,
                                ref,
                                initial: bill,
                              );
                              if (changed) ref.invalidate(billsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () async {
                              final bool confirm = await confirmDelete(context);
                              if (!confirm) return;
                              final int id = _parseInt(bill["id"]) ?? 0;
                              if (id <= 0) return;
                              await ref.read(billsApiProvider).deleteBill(id);
                              ref.invalidate(billsProvider);
                              if (context.mounted) {
                                showInfoSnackbar(context, "Tagihan dihapus");
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        final int id = _parseInt(bill["id"]) ?? 0;
                        if (id <= 0) return;
                        await ref.read(billsApiProvider).updateBill(
                          id,
                          <String, dynamic>{"action": "toggle"},
                        );
                        ref.invalidate(billsProvider);
                        if (context.mounted) {
                          showInfoSnackbar(
                            context,
                            isPaid ? "Tagihan dibuka lagi" : "Tagihan ditandai lunas",
                          );
                        }
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
          message: _apiError(error, "Gagal memuat tagihan"),
          onRetry: () => ref.invalidate(billsProvider),
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

Future<bool> _showBillDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController nameController = TextEditingController(
    text: initial == null ? "" : (initial["name"] ?? "").toString(),
  );
  final TextEditingController amountController = TextEditingController(
    text: initial == null ? "" : (initial["amount"] ?? "").toString(),
  );
  final TextEditingController dueDateController = TextEditingController(
    text: (initial?["dueDate"] ?? 1).toString(),
  );
  final TextEditingController notesController = TextEditingController(
    text: (initial?["notes"] ?? "").toString(),
  );
  String frequency = (initial?["frequency"] ?? "monthly").toString();
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Tagihan" : "Edit Tagihan"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: "Nama tagihan"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dueDateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Tanggal jatuh tempo (1-31)"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                          value: "monthly", child: Text("Bulanan")),
                      DropdownMenuItem(
                          value: "weekly", child: Text("Mingguan")),
                      DropdownMenuItem(value: "yearly", child: Text("Tahunan")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => frequency = value);
                    },
                    decoration: const InputDecoration(labelText: "Frekuensi"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: "Catatan"),
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
                        final int? dueDate =
                            int.tryParse(dueDateController.text);
                        if (nameController.text.trim().isEmpty ||
                            amount == null ||
                            amount <= 0 ||
                            dueDate == null ||
                            dueDate < 1 ||
                            dueDate > 31) {
                          setState(
                              () => errorText = "Data tagihan tidak valid.");
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
                            "amount": amount,
                            "dueDate": dueDate,
                            "frequency": frequency,
                            "notes": notesController.text.trim(),
                          };

                          if (initial == null) {
                            await ref
                                .read(billsApiProvider)
                                .createBill(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref
                                .read(billsApiProvider)
                                .updateBill(id, payload);
                          }

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                          if (context.mounted) {
                            showInfoSnackbar(
                              context,
                              initial == null
                                  ? "Tagihan berhasil ditambahkan"
                                  : "Tagihan berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan tagihan.";
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
