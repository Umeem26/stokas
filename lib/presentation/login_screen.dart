import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validators.dart';
import '../data/providers.dart';
import '../data/repositories/auth_repository.dart';
import 'design/stokas_button.dart';
import 'design/stokas_logo.dart';
import 'design/stokas_tokens.dart';

const loginTagline = 'Uang dan barang, satu catatan.';

class LoginScreen extends ConsumerStatefulWidget {
  /// Pesan dari gerbang sesi, mis. akun nonaktif.
  final String? message;

  const LoginScreen({super.key, this.message});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  SignInException? _error;

  @override
  void initState() {
    super.initState();
    final message = widget.message;
    if (message != null) {
      final failure = message == inactiveAccountMessage ? SignInFailure.inactive : SignInFailure.other;
      _error = SignInException(failure, message);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    SignInException? failure;
    try {
      // Sukses -> gerbang sesi pindah ke beranda lewat onAuthStateChange.
      await ref.read(authRepositoryProvider).signIn(_identifierController.text, _passwordController.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      failure = e is SignInException ? e : SignInException(SignInFailure.other, '$e', e);
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (failure != null) _error = failure;
    });
    if (failure != null) {
      // Siap ketik ulang: password terfokus dan terseleksi.
      _passwordController.selection = TextSelection(baseOffset: 0, extentOffset: _passwordController.text.length);
      _passwordFocus.requestFocus();
    }
  }

  /// Enter di kolom username: pindah ke password bila kosong, selain itu langsung masuk.
  void _onIdentifierSubmitted(String _) {
    if (_passwordController.text.isEmpty) {
      _passwordFocus.requestFocus();
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(StokasSpace.s4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: StokasLogo.lockup(key: Key('login-logo'), height: 48)),
                  const SizedBox(height: StokasSpace.s3),
                  Text(loginTagline, textAlign: TextAlign.center, style: StokasType.bodyLg.copyWith(color: c.inkMuted)),
                  const SizedBox(height: StokasSpace.s6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(StokasRadius.lg),
                      border: Border.all(color: c.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(StokasSpace.s5),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Masuk', style: StokasType.titleLg.copyWith(color: c.ink)),
                              const SizedBox(height: StokasSpace.s4),
                              TextFormField(
                                key: const Key('login-identifier'),
                                controller: _identifierController,
                                // Sengaja tidak dikunci saat memproses (enabled/readOnly): di web input DOM
                                // dilepas sehingga setelah gagal masuk ketikan berikutnya hilang.
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: _onIdentifierSubmitted,
                                decoration: const InputDecoration(
                                  labelText: 'Username atau email',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: validateLoginIdentifier,
                              ),
                              const SizedBox(height: StokasSpace.s4),
                              TextFormField(
                                key: const Key('login-password'),
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                // onEditingComplete (bukan onFieldSubmitted): Enter tidak melepas fokus.
                                onEditingComplete: _submit,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    constraints: const BoxConstraints(minWidth: StokasSpace.tapMin, minHeight: StokasSpace.tapMin),
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: validateLoginPassword,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: StokasSpace.s4),
                                _SignInErrorBanner(error: _error!),
                              ],
                              const SizedBox(height: StokasSpace.s5),
                              StokasButton(
                                key: const Key('login-submit'),
                                label: 'Masuk',
                                expand: true,
                                loading: _isLoading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikon per jenis galat login (selalu bersama teks, bukan warna saja).
IconData signInFailureIcon(SignInFailure failure) => switch (failure) {
      SignInFailure.wrongCredentials => Icons.key_off_outlined,
      SignInFailure.network => Icons.wifi_off,
      SignInFailure.inactive => Icons.block,
      SignInFailure.apiKey => Icons.vpn_key_off_outlined,
      SignInFailure.rateLimited => Icons.hourglass_empty,
      SignInFailure.other => Icons.error_outline,
    };

class _SignInErrorBanner extends StatelessWidget {
  final SignInException error;

  const _SignInErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('login-error'),
        padding: const EdgeInsets.all(StokasSpace.s3),
        decoration: BoxDecoration(
          color: c.negativeSoft,
          borderRadius: BorderRadius.circular(StokasRadius.md),
          border: Border.all(color: c.negative),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(signInFailureIcon(error.failure), size: 20, color: c.negative),
            const SizedBox(width: StokasSpace.s2),
            Expanded(child: Text(error.message, style: StokasType.body.copyWith(color: c.ink))),
          ],
        ),
      ),
    );
  }
}
