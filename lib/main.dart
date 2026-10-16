import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'state/app_store.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final store = AppStore();
  await store.init();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    store.firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase başlatılamadı (yerel mod): $e');
  }
  runApp(DietitianApp(store: store));
}

class DietitianApp extends StatelessWidget {
  final AppStore store;
  const DietitianApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
        child: MaterialApp(
        title: 'Diyetisyen Asistanı',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1B5E20),
          useMaterial3: true,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xFFF6F8F4),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          textTheme: const TextTheme(
            titleLarge: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.5,
              color: Color(0xFF1A1A2E),
            ),
            bodyMedium: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF1A1A2E),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 72,
            indicatorColor: const Color(0xFF1B5E20).withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (states) => states.contains(WidgetState.selected)
                  ? const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF1B5E20),
                    )
                  : const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Color(0xFF6C7280),
                    ),
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

String fmtDay(DateTime d) {
  try {
    return DateFormat.yMMMd('tr_TR').format(d);
  } catch (_) {
    return DateFormat.yMMMd().format(d);
  }
}
