import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';

/// Email/password login + register. Same account on every device
/// sees the same data (cloud sync).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _pass.text.length < 6) {
      setState(() => _error =
          'Geçerli bir e-posta ve en az 6 karakterli şifre girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_registerMode) {
        await auth.createUserWithEmailAndPassword(
            email: email, password: _pass.text);
      } else {
        await auth.signInWithEmailAndPassword(
            email: email, password: _pass.text);
      }
      // AuthGate rebuilds automatically via authStateChanges.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _tr(e));
    } catch (e) {
      setState(() => _error = 'Bir hata oldu: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _tr(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-postayla kayıt bulunamadı. Önce kayıt olun.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı. Giriş yapın.';
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      default:
        return 'Giriş başarısız (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diyetisyen Asistanı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_sync, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              'Aynı hesap, her cihazda aynı veri',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Telefon ve bilgisayarda aynı e-postayla giriş yapın, listeniz ve stoğunuz eşitlensin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Giriş Yap')),
                ButtonSegment(value: true, label: Text('Kayıt Ol')),
              ],
              selected: {_registerMode},
              onSelectionChanged: (s) =>
                  setState(() => _registerMode = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre (en az 6 karakter)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : Text(_registerMode ? 'Kayıt Ol' : 'Giriş Yap'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final store = context.read<AppStore>();
                store.localOnly = true;
                await store.save();
              },
              child: const Text('Hesapsız devam et (bu cihazda kalır)'),
            ),
          ],
        ),
      ),
    );
  }
}
