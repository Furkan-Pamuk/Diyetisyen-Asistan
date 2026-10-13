import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'services/notification_service.dart';
import 'state/app_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final store = AppStore();
  await store.init();
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
        home: const HomeScreen(),
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
