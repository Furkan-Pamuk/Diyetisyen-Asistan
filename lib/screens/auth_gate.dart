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
/// - Logged in -> enables cloud sync, then HomeScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.firebaseReady || store.localOnly) {
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
        if (user == null) return const AuthScreen();
        store.enableSync(user.uid);
        return const HomeScreen();
      },
    );
  }
}
