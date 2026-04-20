import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/presentation/async_state_views.dart";
import "../../../core/presentation/feedback_helpers.dart";
import "../../../core/presentation/mobile_scaffold.dart";
import "../data/ai_api.dart";

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> rows = await ref
          .read(aiApiProvider)
          .getChatHistory();
      _messages
        ..clear()
        ..addAll(
          rows.map(
            (Map<String, dynamic> row) => _ChatMessage(
              role: (row["role"] ?? "assistant").toString(),
              content: (row["content"] ?? "").toString(),
            ),
          ),
        );
      if (mounted) setState(() => _loading = false);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _apiError(e, "Gagal memuat chat AI");
      });
    }
  }

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(role: "user", content: text));
    });

    try {
      final List<Map<String, String>> history = _messages
          .take(_messages.length - 1)
          .map(
            (_ChatMessage msg) => <String, String>{
              "role": msg.role,
              "content": msg.content,
            },
          )
          .toList();

      final Map<String, dynamic> result = await ref.read(aiApiProvider).sendChat(
            message: text,
            history: history,
          );
      final String reply = (result["reply"] ?? "Belum ada balasan").toString();
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: "assistant", content: reply));
        _sending = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showInfoSnackbar(context, _apiError(e, "Gagal mengirim pesan"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      title: "AI Chat",
      currentPath: "/dashboard",
      child: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const AppLoadingView()
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadHistory)
                    : _messages.isEmpty
                        ? const AppEmptyView(
                            title: "Belum ada chat",
                            subtitle: "Tanyakan apa saja tentang kondisi keuanganmu.",
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final _ChatMessage msg = _messages[index];
                              final bool isUser = msg.role == "user";
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? Theme.of(context).colorScheme.primaryContainer
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(msg.content),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: "Tanya soal keuangan...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: Text(_sending ? "..." : "Kirim"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
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

