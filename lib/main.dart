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
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
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
