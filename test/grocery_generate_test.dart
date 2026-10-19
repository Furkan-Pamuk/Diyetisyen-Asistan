import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietitian_flutter/screens/grocery_list_screen.dart';
import 'package:dietitian_flutter/state/app_store.dart';

/// Kullanıcının bildirdiği akış: menü doluyken "Listeyi Oluştur / Yenile"
/// butonuna basınca ekranda kalınmalı, liste dolmalı, hata fırlamamalı.
void main() {
  testWidgets('liste olustur ekranda kalir ve listeyi doldurur',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    store.loadSampleData();
    // Kullanıcı durumu: stoklar bitmiş, menü dolu.
    for (final item in store.inventory) {
      item.currentStock = 0;
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: GroceryListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listeyi Oluştur / Yenile'));
    await tester.pumpAndSettle();

    // Hâlâ alışveriş ekranındayız, liste dolu.
    expect(find.text('Alışveriş Listesi'), findsOneWidget);
    expect(store.groceryItems.isNotEmpty, isTrue);
    // Örnek menüden en az bir bilinen ürün listede olmalı.
    expect(
      store.groceryItems.any((e) => e.name == 'Domates'),
      isTrue,
    );
  });
}
