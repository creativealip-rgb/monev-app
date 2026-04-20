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
    final AsyncValue<List<Map<String, dynamic>>> items = ref.watch(goalsProvider);
    final NumberFormat currency = NumberFormat.currency(
      locale: "id_ID",
      symbol: "Rp ",
      decimalDigits: 0,
    );

    return MobileScaffold(
      title: "Goals",
      currentPath: "/goals",
      child: items.when(
        data: (List<Map<String, dynamic>> data) {
          if (data.isEmpty) {
            return AppEmptyView(
              title: "Belum ada goals",
              subtitle: "Buat target finansial pertama kamu sekarang.",
              action: FilledButton(
                onPressed: () async {
                  final bool changed = await _showGoalDialog(context, ref);
                  if (changed) ref.invalidate(goalsProvider);
                },
                child: const Text("Tambah Goal"),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(goalsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> goal = data[index];
                final num target = (goal["targetAmount"] ?? 0) as num;
                final num current = (goal["currentAmount"] ?? 0) as num;
                final double ratio = target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();

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
                                await ref
                                    .read(goalsApiProvider)
                                    .deleteGoal(id);
                                ref.invalidate(goalsProvider);
                                if (context.mounted) {
                                  showInfoSnackbar(context, "Goal dihapus");
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
              },
            ),
          );
        },
        loading: () => const AppLoadingView(),
        error: (Object error, StackTrace _) => AppErrorView(
          message: _apiError(error, "Gagal memuat goals"),
          onRetry: () => ref.invalidate(goalsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool changed = await _showGoalDialog(context, ref);
          if (changed) ref.invalidate(goalsProvider);
        },
        child: const Icon(Icons.add),
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
            title: Text(initial == null ? "Tambah Goal" : "Edit Goal"),
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
                    decoration: const InputDecoration(labelText: "Progress saat ini"),
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
                        final double? target = double.tryParse(targetController.text);
                        final double? current = double.tryParse(currentController.text);
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
                          final Map<String, dynamic> payload = <String, dynamic>{
                            "name": nameController.text.trim(),
                            "targetAmount": target,
                            "currentAmount": current,
                          };

                          if (initial == null) {
                            await ref.read(goalsApiProvider).createGoal(payload);
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
                                  ? "Goal berhasil ditambahkan"
                                  : "Goal berhasil diperbarui",
                            );
                          }
                        } on DioException catch (e) {
                          final dynamic body = e.response?.data;
                          setState(() {
                            errorText = body is Map<String, dynamic> && body["error"] != null
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

