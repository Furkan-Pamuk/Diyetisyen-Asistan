import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietitian_flutter/screens/supplier_orders_screen.dart';
import 'package:dietitian_flutter/state/app_store.dart';

/// Sipariş formu: tedarikçi + tarihler + birden fazla ürün satırı
/// kaydedilince sipariş kalemleriyle birlikte saklanmalı.
void main() {
  testWidgets('yeni siparis cok urunlu kaydedilir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    store.loadSampleData();
    final before = store.supplierOrders.length;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return FilledButton(
                onPressed: () => showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => const OrderFormSheet(existing: null),
                ),
                child: const Text('AC'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AC'));
    await tester.pumpAndSettle();

    // Başlık + ürün satırı doldur.
    await tester.enterText(
        find.widgetWithText(TextField, 'Başlık (örn. Haftalık sebze)'),
        'Hal siparişi');
    await tester.tap(find.text('Ürün Ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Ürün adı'), 'Domates');
    await tester.pump();
    // Önerilerden Domates'i seç.
    final option = find.widgetWithText(ListTile, 'Domates');
    if (option.evaluate().isNotEmpty) {
      await tester.tap(option.first);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
        find.widgetWithText(TextField, 'Miktar'), '500');
    await tester.pump();

    final saveBtn = find.text('Kaydet');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(store.supplierOrders.length, before + 1);
    final order = store.supplierOrders.last;
    expect(order.items.length, 1);
    expect(order.items.first.name, 'Domates');
    expect(order.items.first.orderedQty, 500);
    expect(order.items.first.itemId, isNotNull);
  });
}
