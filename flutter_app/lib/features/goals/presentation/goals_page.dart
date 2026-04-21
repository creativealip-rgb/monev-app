import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/goals_api.dart";

final FutureProvider<List<Map<String, dynamic>>> goalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) async {
  return ref.read(goalsApiProvider).getGoals();
});

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> items =
        ref.watch(goalsProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Target",
      subtitle: "Progres tujuan finansialmu",
      currentPath: "/goals",
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showGoalDialog(context, ref);
          if (changed) ref.invalidate(goalsProvider);
        },
        child: const Icon(Icons.add),
      ),
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada target",
              subtitle: "Buat target finansial pertama kamu sekarang.",
              icon: Icons.flag_outlined,
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showGoalDialog(context, ref);
                  if (changed) ref.invalidate(goalsProvider);
                },
                child: const Text("Tambah Target"),
              ),
            );
          }
          final num targetTotal = data.fold<num>(
            0,
            (num sum, Map<String, dynamic> goal) =>
                sum + ((goal["targetAmount"] ?? 0) as num),
          );
          final num currentTotal = data.fold<num>(
            0,
            (num sum, Map<String, dynamic> goal) =>
                sum + ((goal["currentAmount"] ?? 0) as num),
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(goalsProvider.future),
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
                            label: "Total Target",
                            value: currency.format(targetTotal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryItem(
                            label: "Terkumpul",
                            value: currency.format(currentTotal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...data.map((Map<String, dynamic> goal) {
                  final num target = (goal["targetAmount"] ?? 0) as num;
                  final num current = (goal["currentAmount"] ?? 0) as num;
                  final double ratio =
                      target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();

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
                                  (goal["name"] ?? "-").toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () async {
                                  final bool changed = await _showGoalDialog(
                                    context,
                                    ref,
                                    initial: goal,
                                  );
                                  if (changed) ref.invalidate(goalsProvider);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () async {
                                  final bool confirm = await confirmDelete(context);
                                  if (!confirm) return;
                                  final int id = _parseInt(goal["id"]) ?? 0;
                                  if (id <= 0) return;
                                  await ref.read(goalsApiProvider).deleteGoal(id);
                                  ref.invalidate(goalsProvider);
                                  if (context.mounted) {
                                    showInfoSnackbar(context, "Target dihapus");
                                  }
                                },
                              ),
                            ],
                          ),
                          Text(
                            "${currency.format(current)} / ${currency.format(target)}",
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: ratio),
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
          message: _apiError(error, "Gagal memuat goals"),
          onRetry: () => ref.invalidate(goalsProvider),
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

Future<bool> _showGoalDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? initial,
}) async {
  final TextEditingController nameController = TextEditingController(
    text: initial == null ? "" : (initial["name"] ?? "").toString(),
  );
  final TextEditingController targetController = TextEditingController(
    text: initial == null ? "" : (initial["targetAmount"] ?? "").toString(),
  );
  final TextEditingController currentController = TextEditingController(
    text: initial == null ? "0" : (initial["currentAmount"] ?? 0).toString(),
  );
  String? errorText;
  bool isSaving = false;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(initial == null ? "Tambah Target" : "Edit Target"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nama goal"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Target"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Progress saat ini"),
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
                        final double? target =
                            double.tryParse(targetController.text);
                        final double? current =
                            double.tryParse(currentController.text);
                        if (nameController.text.trim().isEmpty ||
                            target == null ||
                            target <= 0 ||
                            current == null ||
                            current < 0) {
                          setState(() => errorText = "Data goal tidak valid.");
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
                            "targetAmount": target,
                            "currentAmount": current,
                          };

                          if (initial == null) {
                            await ref
                                .read(goalsApiProvider)
                                .createGoal(payload);
                          } else {
                            final int id = _parseInt(initial["id"]) ?? 0;
                            if (id <= 0) return;
                            await ref.read(goalsApiProvider).updateGoal(
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
                                  ? "Target berhasil ditambahkan"
                                  : "Target berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> &&
                                    body["error"] != null
                                ? body["error"].toString()
                                : "Gagal menyimpan goal.";
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
