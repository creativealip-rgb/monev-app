import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/investments_api.dart";

final FutureProvider<Map<String, dynamic>> investmentsSummaryProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) async {
  return ref.read(investmentsApiProvider).getSummary();
});

class InvestmentsPage extends ConsumerWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>> summary = ref.watch(
      investmentsSummaryProvider,
    );
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Investasi",
      currentPath: "/dashboard",
      child: summary.when(
        data: (Map<String, dynamic> data) {
          final List<Map<String, dynamic>> items =
              ((data["items"] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>());
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: <Widget>[
                        _SummaryRow(
                          label: "Total Value",
                          value: currency.format((data["totalValue"] ?? 0) as num),
                        ),
                        _SummaryRow(
                          label: "Total Profit",
                          value: currency.format((data["totalProfit"] ?? 0) as num),
                        ),
                        _SummaryRow(
                          label: "Profit %",
                          value: "${((data["profitPercent"] ?? 0) as num).toStringAsFixed(2)}%",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? AppEmptyView(
                        title: "Belum ada investasi",
                        action: FilledButton(
                          onPressed: () async {
                            final bool changed = await _showInvestmentDialog(context, ref);
                            if (changed) ref.invalidate(investmentsSummaryProvider);
                          },
                          child: const Text("Tambah Investasi"),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.refresh(investmentsSummaryProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, dynamic> item = items[index];
                            final num value = ((item["quantity"] ?? 0) as num) *
                                ((item["currentPrice"] ?? 0) as num);
                            return Card(
                              child: ListTile(
                                title: Text((item["name"] ?? "-").toString()),
                                subtitle: Text((item["type"] ?? "other").toString()),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      currency.format(value),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        final bool changed = await _showInvestmentDialog(
                                          context,
                                          ref,
                                          initial: item,
                                        );
                                        if (changed) {
                                          ref.invalidate(investmentsSummaryProvider);
                                        }
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        final bool confirm = await confirmDelete(context);
                                        if (!confirm) return;
                                        final int id = _parseInt(item["id"]) ?? 0;
                                        if (id <= 0) return;
                                        await ref.read(investmentsApiProvider).deleteInvestment(id);
                                        ref.invalidate(investmentsSummaryProvider);
                                        if (context.mounted) {
                                          showInfoSnackbar(context, "Investasi dihapus");
                                        }
                                      },
                                      icon: const Icon(Icons.delete, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat investasi"),
          onRetry: () => ref.invalidate(investmentsSummaryProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showInvestmentDialog(context, ref);
          if (changed) ref.invalidate(investmentsSummaryProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

Future<bool> _showInvestmentDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController nameController = TextEditingController(
    text: (initial?["name"] ?? "").toString(),
  );
  final TextEditingController quantityController = TextEditingController(
    text: (initial?["quantity"] ?? "").toString(),
  );
  final TextEditingController avgBuyPriceController = TextEditingController(
    text: (initial?["avgBuyPrice"] ?? "").toString(),
  );
  final TextEditingController currentPriceController = TextEditingController(
    text: (initial?["currentPrice"] ?? "").toString(),
  );
  String type = (initial?["type"] ?? "stock").toString();
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Investasi" : "Edit Investasi"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nama"),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: "stock", child: Text("Stock")),
                      DropdownMenuItem(value: "crypto", child: Text("Crypto")),
                      DropdownMenuItem(value: "mutual_fund", child: Text("Mutual Fund")),
                      DropdownMenuItem(value: "gold", child: Text("Gold")),
                      DropdownMenuItem(value: "bond", child: Text("Bond")),
                      DropdownMenuItem(value: "other", child: Text("Other")),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => type = value);
                    },
                    decoration: const InputDecoration(labelText: "Tipe"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantity"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: avgBuyPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Avg Buy Price"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Current Price"),
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
                        final double? quantity = double.tryParse(quantityController.text);
                        final double? avgBuyPrice = double.tryParse(avgBuyPriceController.text);
                        final double? currentPrice = double.tryParse(currentPriceController.text);
                        if (nameController.text.trim().isEmpty ||
                            quantity == null ||
                            quantity <= 0 ||
                            avgBuyPrice == null ||
                            avgBuyPrice <= 0 ||
                            currentPrice == null ||
                            currentPrice <= 0) {
                          setState(() => errorText = "Data investasi tidak valid.");
                          return;
                        }

                        setState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        try {
                          final Map<String, dynamic> payload = <String, dynamic>{
                            "name": nameController.text.trim(),
                            "type": type,
                            "quantity": quantity,
                            "avgBuyPrice": avgBuyPrice,
                            "currentPrice": currentPrice,
                          };
                          if (initial == null) {
                            await ref.read(investmentsApiProvider).createInvestment(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref.read(investmentsApiProvider).updateInvestment(id, payload);
                          }

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> && body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan investasi.";
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

