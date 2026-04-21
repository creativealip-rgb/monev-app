import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/recurring_api.dart";

final FutureProvider<List<Map<String, dynamic>>> recurringProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(recurringApiProvider).getRecurring();
});

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> items =
        ref.watch(recurringProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Transaksi Berkala",
      subtitle: "Otomasi pemasukan dan pengeluaran rutin",
      currentPath: "/recurring",
      showBottomNavigation: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showRecurringDialog(context, ref);
          if (changed) ref.invalidate(recurringProvider);
        },
        child: const Icon(Icons.add),
      ),
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada transaksi berkala",
              subtitle:
                  "Tambahkan transaksi yang berulang agar pencatatan lebih rapi.",
              icon: Icons.repeat_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showRecurringDialog(context, ref);
                  if (changed) ref.invalidate(recurringProvider);
                },
                child: const Text("Tambah Berkala"),
              ),
            );
          }
          final int activeCount = data.where(
            (Map<String, dynamic> item) => (item["isActive"] ?? true) == true,
          ).length;
          final num monthlyEstimate = data.fold<num>(
            0,
            (num sum, Map<String, dynamic> item) {
              final num amount = (item["amount"] ?? 0) as num;
              final String frequency = (item["frequency"] ?? "monthly").toString();
              final num multiplier = switch (frequency) {
                "daily" => 30,
                "weekly" => 4,
                _ => 1,
              };
              return sum + (amount * multiplier);
            },
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(recurringProvider.future),
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
                            label: "Rule Aktif",
                            value: "$activeCount/${data.length}",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryItem(
                            label: "Estimasi/Bulan",
                            value: currency.format(monthlyEstimate),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...data.map((Map<String, dynamic> item) {
                  final bool isActive = (item["isActive"] ?? true) == true;
                  return Card(
                    child: ListTile(
                      title: Text((item["description"] ?? "-").toString()),
                      subtitle: Text(
                        "${(item["frequency"] ?? "monthly").toString()} • ${(item["type"] ?? "expense").toString()}",
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
                              Text(isActive ? "Aktif" : "Nonaktif"),
                            ],
                          ),
                          IconButton(
                            onPressed: () async {
                              final bool changed = await _showRecurringDialog(
                                context,
                                ref,
                                initial: item,
                              );
                              if (changed) ref.invalidate(recurringProvider);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              final bool confirm = await confirmDelete(context);
                              if (!confirm) return;
                              final int id = _parseInt(item["id"]) ?? 0;
                              if (id <= 0) return;
                              await ref.read(recurringApiProvider).deleteRecurring(id);
                              ref.invalidate(recurringProvider);
                              if (context.mounted) {
                                showInfoSnackbar(context, "Transaksi berkala dihapus");
                              }
                            },
                            icon: const Icon(Icons.delete, size: 18),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final int id = _parseInt(item["id"]) ?? 0;
                        if (id <= 0) return;
                        await ref.read(recurringApiProvider).updateRecurring(
                          id,
                          <String, dynamic>{"isActive": !isActive},
                        );
                        ref.invalidate(recurringProvider);
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
          message: _apiError(error, "Gagal memuat recurring"),
          onRetry: () => ref.invalidate(recurringProvider),
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

Future<bool> _showRecurringDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController amountController = TextEditingController(
    text: (initial?["amount"] ?? "").toString(),
  );
  final TextEditingController descriptionController = TextEditingController(
    text: (initial?["description"] ?? "").toString(),
  );
  String frequency = (initial?["frequency"] ?? "monthly").toString();
  String type = (initial?["type"] ?? "expense").toString();
  bool isActive = (initial?["isActive"] ?? true) == true;
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Berkala" : "Edit Berkala"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: "Deskripsi"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: "daily", child: Text("Harian")),
                      DropdownMenuItem(
                          value: "weekly", child: Text("Mingguan")),
                      DropdownMenuItem(
                          value: "monthly", child: Text("Bulanan")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => frequency = value);
                    },
                    decoration: const InputDecoration(labelText: "Frekuensi"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                          value: "expense", child: Text("Pengeluaran")),
                      DropdownMenuItem(
                          value: "income", child: Text("Pemasukan")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => type = value);
                    },
                    decoration: const InputDecoration(labelText: "Tipe"),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (bool value) => setState(() => isActive = value),
                    title: const Text("Aktif"),
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
                        final double? amount =
                            double.tryParse(amountController.text);
                        if (amount == null ||
                            amount <= 0 ||
                            descriptionController.text.trim().isEmpty) {
                          setState(
                              () => errorText = "Data recurring tidak valid.");
                          return;
                        }

                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          final Map<String, dynamic> payload =
                              <String, dynamic>{
                            "amount": amount,
                            "description": descriptionController.text.trim(),
                            "frequency": frequency,
                            "type": type,
                            "isActive": isActive,
                          };
                          if (initial == null) {
                            await ref
                                .read(recurringApiProvider)
                                .createRecurring(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref
                                .read(recurringApiProvider)
                                .updateRecurring(id, payload);
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
                                : "Gagal menyimpan recurring.";
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
