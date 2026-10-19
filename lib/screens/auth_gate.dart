import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// Decides the first screen:
/// - Firebase missing -> local HomeScreen.
/// - "Continue without account" chosen -> local HomeScreen.
/// - Logged out -> AuthScreen.
/// - Logged in -> enables cloud sync (once per account), then HomeScreen.
///
/// Not: senkron build içinde DEĞİL, post-frame'de ve uid değişince
/// bir kez başlatılır (build sırasında notifyListeners döngüsünü önler).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _syncedUid;

  void _ensureSync(String? uid) {
    if (uid == null || uid == _syncedUid) return;
    _syncedUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppStore>().enableSync(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.firebaseReady || store.localOnly) {
      _syncedUid = null;
      return const HomeScreen();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          _syncedUid = null;
          return const AuthScreen();
        }
        _ensureSync(user.uid);
        return const HomeScreen();
      },
    );
  }
}
