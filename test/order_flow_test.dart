import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietitian_flutter/models/supplier_order.dart';
import 'package:dietitian_flutter/screens/supplier_orders_screen.dart';
import 'package:dietitian_flutter/state/app_store.dart';
import 'package:dietitian_flutter/widgets/order_qty_sheet.dart';

/// Sipariş merkezi: durum sekmeleri filtreler, "Sipariş Ver"
/// penceresi doğrudan planlı sipariş açar (sepet yok).
void main() {
  testWidgets('durum sekmeleri siparişleri süzer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    store.loadSampleData();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: SupplierOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tümü: örnek 3 sipariş görünür.
    expect(find.text('Haftalık sebze siparişi'), findsOneWidget);
    expect(find.text('Et & süt alımı'), findsOneWidget);
    expect(find.text('Kuru gıda ikmali'), findsOneWidget);

    // Sipariş Verilecekler: yalnız planlanmış.
    await tester.ensureVisible(find.text('Sipariş Verilecekler (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sipariş Verilecekler (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Haftalık sebze siparişi'), findsOneWidget);
    expect(find.text('Et & süt alımı'), findsNothing);
    expect(find.text('Kuru gıda ikmali'), findsNothing);

    // Teslimatı Beklenenler: yalnız sipariş verilmiş.
    await tester.ensureVisible(find.text('Teslimatı Beklenenler (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teslimatı Beklenenler (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Et & süt alımı'), findsOneWidget);
    expect(find.text('Haftalık sebze siparişi'), findsNothing);

    // Teslim Alınanlar: yalnız teslim alınmış.
    await tester.ensureVisible(find.text('Teslim Alınanlar (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teslim Alınanlar (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Kuru gıda ikmali'), findsOneWidget);
    expect(find.text('Et & süt alımı'), findsNothing);
  });

  testWidgets('sipariş ver penceresi planlı sipariş açar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    store.loadSampleData();
    final item = store.inventory.first;
    final before = store.supplierOrders.length;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => FilledButton(
                onPressed: () => openOrderQtySheet(ctx,
                    itemId: item.id, suggestedQty: 5),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sipariş Aç'));
    await tester.pumpAndSettle();

    expect(store.supplierOrders.length, before + 1);
    final created = store.supplierOrders.last;
    expect(created.status, SupplierOrderStatus.scheduled);
    expect(created.items.length, 1);
    expect(created.items.first.itemId, item.id);
    expect(created.items.first.orderedQty, 5);
  });
}
