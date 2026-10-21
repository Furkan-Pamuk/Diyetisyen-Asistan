import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietitian_flutter/screens/agenda_screen.dart';
import 'package:dietitian_flutter/state/app_store.dart';

/// Aylık ajanda: bir güne birden fazla not girilince kutuda
/// sığdığı kadar not alt alta görünür (eski "+N" tek satırı yerine).
void main() {
  testWidgets('gun kutusu birden fazla notu alt alta gosterir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await store.addAgendaEntry(today, 'Sabah notu');
    await store.addAgendaEntry(today, 'Oglen notu');
    await store.addAgendaEntry(today, 'Aksam notu');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: AgendaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Üç not da takvim kutusunda (kısaltılmış da olsa) görünür.
    expect(find.text('Sabah notu', findRichText: true), findsWidgets);
    expect(find.text('Oglen notu', findRichText: true), findsWidgets);
    expect(find.text('Aksam notu', findRichText: true), findsWidgets);
    // Eski tek-satır özeti artık yok.
    expect(find.textContaining('(+2)'), findsNothing);
  });

  testWidgets('dar ekranda sigmayan notlar +N ile ozetlenir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 1; i <= 6; i++) {
      await store.addAgendaEntry(today, 'Not $i');
    }

    // Telefon genişliği: kutu ~46px, en fazla 2-3 satır sığar.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: AgendaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Taşma hatası yok, fazla notlar +N göstergesinde.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('+'), findsWidgets);
  });
}
