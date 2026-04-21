import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../data/auth_api.dart";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authApiProvider).login(
            email: _emailController.text,
            password: _passwordController.text,
          );

      if (!mounted) return;
      context.go("/dashboard");
    } on DioException catch (error) {
      final dynamic body = error.response?.data;
      final String apiMessage =
          body is Map<String, dynamic> ? (body["error"]?.toString() ?? "") : "";
      setState(() {
        _errorMessage = apiMessage.isNotEmpty
            ? apiMessage
            : "Login gagal. Periksa email/password.";
      });
    } catch (error, stackTrace) {
      debugPrint("Login failed unexpectedly: $error");
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _errorMessage = "Terjadi kesalahan. Coba lagi.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFCEE2FF), Color(0xFFF4F8FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCE8FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.wallet_rounded,
                                  color: Color(0xFF1E56C7)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE7F0FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "Monev Mobile",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E56C7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Selamat datang di Monev",
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F2547),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  const Text(
                                    "Masuk dengan akun Monev Web untuk lanjut memantau keuanganmu.",
                                    style: TextStyle(color: Color(0xFF4E6B94)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: const Icon(Icons.login_rounded),
                          label: Text(
                              _isSubmitting ? "Memproses..." : "Masuk ke Akun"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
