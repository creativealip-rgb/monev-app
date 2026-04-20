import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/budgets_api.dart";

final FutureProvider<List<Map<String, dynamic>>> budgetsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(budgetsApiProvider).getBudgets();
});

final FutureProvider<List<Map<String, dynamic>>> budgetCategoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(budgetsApiProvider).getCategories();
});

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> items = ref.watch(
      budgetsProvider,
    );
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Budget",
      currentPath: "/budgets",
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada budget",
              subtitle: "Atur budget pertama supaya pengeluaran lebih terkontrol.",
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showBudgetDialog(context, ref);
                  if (changed) ref.invalidate(budgetsProvider);
                },
                child: const Text("Tambah Budget"),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(budgetsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> item = data[index];
                final num amount = (item["amount"] ?? 0) as num;
                final num spent = (item["spent"] ?? 0) as num;
                final double ratio = amount <= 0 ? 0 : (spent / amount).clamp(0, 1).toDouble();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                (item["category"] ?? "-").toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () async {
                                final bool changed = await _showBudgetDialog(
                                  context,
                                  ref,
                                  initial: item,
                                );
                                if (changed) ref.invalidate(budgetsProvider);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () async {
                                final bool confirm = await confirmDelete(context);
                                if (!confirm) return;
                                final int id = _parseInt(item["id"]) ?? 0;
                                if (id <= 0) return;
                                await ref
                                    .read(budgetsApiProvider)
                                    .deleteBudget(id);
                                ref.invalidate(budgetsProvider);
                                if (context.mounted) {
                                  showInfoSnackbar(context, "Budget dihapus");
                                }
                              },
                            ),
                          ],
                        ),
                        Text(
                          "${currency.format(spent)} / ${currency.format(amount)}",
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: ratio),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat budget"),
          onRetry: () => ref.invalidate(budgetsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showBudgetDialog(context, ref);
          if (changed) ref.invalidate(budgetsProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<bool> _showBudgetDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final DateTime now = DateTime.now();
  final TextEditingController amountController = TextEditingController(
    text: initial == null ? "" : (initial["amount"] ?? "").toString(),
  );
  int month = _parseInt(initial?["month"]) ?? now.month;
  int year = _parseInt(initial?["year"]) ?? now.year;
  int? categoryId = _parseInt(initial?["categoryId"]);
  bool enableRollover = (initial?["enableRollover"] ?? false) == true;
  String? errorText;
  bool isSaving = false;

  final List<Map<String, dynamic>> categories = await ref.read(
    budgetCategoriesProvider.future,
  );
  if (categoryId == null && categories.isNotEmpty) {
    categoryId = _parseInt(categories.first["id"]);
  }

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Budget" : "Edit Budget"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (initial == null) ...<Widget>[
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      items: categories
                          .map(
                            (Map<String, dynamic> category) => DropdownMenuItem<int>(
                              value: _parseInt(category["id"]),
                              child: Text((category["name"] ?? "-").toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) => setState(() => categoryId = value),
                      decoration: const InputDecoration(labelText: "Kategori"),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah budget"),
                  ),
                  const SizedBox(height: 8),
                  if (initial == null) ...<Widget>[
                    DropdownButtonFormField<int>(
                      value: month,
                      items: List<DropdownMenuItem<int>>.generate(
                        12,
                        (int i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text("Bulan ${i + 1}"),
                        ),
                      ),
                      onChanged: (int? value) {
                        if (value != null) setState(() => month = value);
                      },
                      decoration: const InputDecoration(labelText: "Bulan"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: year.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (String value) {
                        final int? parsed = int.tryParse(value);
                        if (parsed != null) year = parsed;
                      },
                      decoration: const InputDecoration(labelText: "Tahun"),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    value: enableRollover,
                    onChanged: (bool value) => setState(() => enableRollover = value),
                    title: const Text("Aktifkan rollover"),
                    contentPadding: EdgeInsets.zero,
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
                        final double? amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          setState(() => errorText = "Jumlah budget tidak valid.");
                          return;
                        }
                        if (initial == null && categoryId == null) {
                          setState(() => errorText = "Kategori wajib dipilih.");
                          return;
                        }

                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          if (initial == null) {
                            await ref.read(budgetsApiProvider).createBudget(<String, dynamic>{
                              "categoryId": categoryId,
                              "amount": amount,
                              "month": month,
                              "year": year,
                              "enableRollover": enableRollover,
                            });
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref.read(budgetsApiProvider).updateBudget(
                                  id,
                                  <String, dynamic>{
                                    "amount": amount,
                                    "enableRollover": enableRollover,
                                  },
                                );
                          }

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                          if (context.mounted) {
                            showInfoSnackbar(
                              context,
                              initial == null
                                  ? "Budget berhasil ditambahkan"
                                  : "Budget berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> && body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan budget.";
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

