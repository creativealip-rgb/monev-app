import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../../accounts/data/accounts_api.dart";
import "../data/transactions_api.dart";

final FutureProvider<List<Map<String, dynamic>>> transactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(transactionsApiProvider).getTransactions();
});

final FutureProvider<List<Map<String, dynamic>>> transactionCategoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(transactionsApiProvider).getCategories();
});

final FutureProvider<List<Map<String, dynamic>>> transactionAccountsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(accountsApiProvider).getAccounts();
});

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> items = ref.watch(
      transactionsProvider,
    );

    return MobileScaffold(
      title: "Transaksi",
      subtitle: "Catatan pemasukan dan pengeluaran",
      currentPath: "/transactions",
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final String? action = await showModalBottomSheet<String>(
            context: context,
            builder: (BuildContext context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text("Tambah transaksi"),
                      onTap: () => Navigator.of(context).pop("add"),
                    ),
                    ListTile(
                      leading: const Icon(Icons.upload_file_outlined),
                      title: const Text("Import transaksi (CSV)"),
                      onTap: () => Navigator.of(context).pop("import"),
                    ),
                  ],
                ),
              );
            },
          );

          if (!context.mounted || action == null) return;
          if (action == "add") {
            final bool changed = await _showTransactionDialog(context, ref);
            if (changed) ref.invalidate(transactionsProvider);
            return;
          }

          if (action == "import") {
            final bool changed = await _showImportDialog(context, ref);
            if (changed) ref.invalidate(transactionsProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada transaksi",
              subtitle: "Tambah transaksi pertama untuk mulai pantau cashflow.",
              icon: Icons.receipt_long_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed =
                      await _showTransactionDialog(context, ref);
                  if (changed) ref.invalidate(transactionsProvider);
                },
                child: const Text("Tambah Transaksi"),
              ),
            );
          }

          final NumberFormat currency = NumberFormat.currency(
            locale: "id_ID",
            symbol: "Rp ",
            decimalDigits: 0,
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(transactionsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> item = data[index];
                final num amount = (item["amount"] ?? 0) as num;
                final String type = (item["type"] ?? "expense").toString();
                final Color amountColor = switch (type) {
                  "income" => Colors.green,
                  "expense" => Colors.red,
                  _ => Colors.blue,
                };

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: amountColor.withValues(alpha: 0.14),
                      child: Icon(
                        switch (type) {
                          "income" => Icons.south_west_rounded,
                          "expense" => Icons.north_east_rounded,
                          _ => Icons.compare_arrows_rounded,
                        },
                        color: amountColor,
                        size: 18,
                      ),
                    ),
                    title: Text((item["description"] ?? "-").toString()),
                    subtitle: Text(
                        (item["categoryName"] ?? "Tanpa kategori").toString()),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          currency.format(amount),
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () async {
                                final bool changed =
                                    await _showTransactionDialog(
                                  context,
                                  ref,
                                  initial: item,
                                );
                                if (changed) {
                                  ref.invalidate(transactionsProvider);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () async {
                                final bool confirm =
                                    await confirmDelete(context);
                                if (!confirm) return;
                                final int id = _parseInt(item["id"]) ?? 0;
                                if (id <= 0) return;
                                await ref
                                    .read(transactionsApiProvider)
                                    .deleteTransaction(id);
                                ref.invalidate(transactionsProvider);
                                if (context.mounted) {
                                  showInfoSnackbar(
                                      context, "Transaksi dihapus");
                                }
                              },
                            ),
                          ],
                        ),
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
          message: _apiError(error, "Gagal memuat transaksi"),
          onRetry: () => ref.invalidate(transactionsProvider),
        ),
      ),
    );
  }
}

Future<bool> _showImportDialog(BuildContext context, WidgetRef ref) async {
  final TextEditingController csvController = TextEditingController();
  String? errorText;
  bool isImporting = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text("Import Transaksi CSV"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    "Format per baris: amount,description,type,category,date\n"
                    "Contoh: 25000,Makan siang,expense,Makan & Minuman,2026-04-20",
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: csvController,
                    minLines: 8,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      hintText: "amount,description,type,category,date",
                      border: OutlineInputBorder(),
                    ),
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
                onPressed: isImporting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text("Batal"),
              ),
              FilledButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        final List<Map<String, dynamic>> rows =
                            _parseImportRows(
                          csvController.text,
                        );
                        if (rows.isEmpty) {
                          setState(() {
                            errorText =
                                "Data CSV kosong atau format tidak valid.";
                          });
                          return;
                        }

                        setState(() {
                          isImporting = true;
                          errorText = null;
                        });

                        try {
                          final Map<String, dynamic> stats = await ref
                              .read(transactionsApiProvider)
                              .importTransactions(rows);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                          if (context.mounted) {
                            showInfoSnackbar(
                              context,
                              "Import selesai. Berhasil: ${stats["imported"] ?? 0}, Gagal: ${stats["failed"] ?? 0}",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal import transaksi.";
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setState(() => isImporting = false);
                          }
                        }
                      },
                child: Text(isImporting ? "Mengimpor..." : "Import"),
              ),
            ],
          );
        },
      );
    },
  );

  return result == true;
}

Future<bool> _showTransactionDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController amountController = TextEditingController(
    text: initial == null ? "" : (initial["amount"] ?? "").toString(),
  );
  final TextEditingController descController = TextEditingController(
    text: initial == null ? "" : (initial["description"] ?? "").toString(),
  );
  String type = (initial?["type"] ?? "expense").toString();
  int? categoryId = _parseInt(initial?["categoryId"]);
  int? accountId = _parseInt(initial?["accountId"]);
  String? errorText;
  bool isSaving = false;

  final List<Map<String, dynamic>> categories = await ref.read(
    transactionCategoriesProvider.future,
  );
  final List<Map<String, dynamic>> accounts = await ref.read(
    transactionAccountsProvider.future,
  );

  if (categoryId == null && categories.isNotEmpty) {
    categoryId = _parseInt(categories.first["id"]);
  }

  if (accountId == null && accounts.isNotEmpty) {
    accountId = _parseInt(accounts.first["id"]);
  }
  if (!context.mounted) return false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title:
                Text(initial == null ? "Tambah Transaksi" : "Edit Transaksi"),
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
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Deskripsi"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                          value: "expense", child: Text("Pengeluaran")),
                      DropdownMenuItem(
                          value: "income", child: Text("Pemasukan")),
                      DropdownMenuItem(
                          value: "transfer", child: Text("Transfer")),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() => type = value);
                    },
                    decoration: const InputDecoration(labelText: "Tipe"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    items: categories
                        .map(
                          (Map<String, dynamic> category) =>
                              DropdownMenuItem<int>(
                            value: _parseInt(category["id"]),
                            child: Text((category["name"] ?? "-").toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) =>
                        setState(() => categoryId = value),
                    decoration: const InputDecoration(labelText: "Kategori"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: accountId,
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text("Tanpa akun"),
                      ),
                      ...accounts.map(
                        (Map<String, dynamic> account) =>
                            DropdownMenuItem<int?>(
                          value: _parseInt(account["id"]),
                          child: Text((account["name"] ?? "-").toString()),
                        ),
                      ),
                    ],
                    onChanged: (int? value) =>
                        setState(() => accountId = value),
                    decoration: const InputDecoration(labelText: "Akun"),
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
                            categoryId == null) {
                          setState(() {
                            errorText = "Pastikan jumlah dan kategori valid.";
                          });
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
                            "description": descController.text.trim(),
                            "type": type,
                            "categoryId": categoryId,
                            "paymentMethod": "cash",
                            if (accountId != null) "accountId": accountId,
                          };

                          if (initial == null) {
                            await ref
                                .read(transactionsApiProvider)
                                .createTransaction(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref
                                .read(transactionsApiProvider)
                                .updateTransaction(
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
                                  ? "Transaksi berhasil ditambahkan"
                                  : "Transaksi berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan transaksi.";
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

List<Map<String, dynamic>> _parseImportRows(String input) {
  final List<String> lines = input
      .split(RegExp(r"\r?\n"))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();

  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  for (final String line in lines) {
    final List<String> parts = line.split(",");
    if (parts.length < 2) continue;

    final String amountRaw = parts[0].trim();
    final double? amount = double.tryParse(amountRaw);
    if (amount == null || amount == 0) continue;

    final String description = parts[1].trim();
    final String type =
        parts.length > 2 ? parts[2].trim().toLowerCase() : "expense";
    final String category = parts.length > 3 ? parts[3].trim() : "Lainnya";
    final String? date =
        parts.length > 4 && parts[4].trim().isNotEmpty ? parts[4].trim() : null;

    rows.add(<String, dynamic>{
      "amount": amount,
      "description": description.isEmpty ? "Imported Transaction" : description,
      "type": (type == "income" || type == "transfer") ? type : "expense",
      "category": category,
      if (date != null) "date": date,
    });
  }
  return rows;
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
