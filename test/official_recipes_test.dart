import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietitian_flutter/data/official_recipes.dart';
import 'package:dietitian_flutter/state/app_store.dart';

/// Resmi gramaj listesi (EK-1) içe aktarma: sayı doğruluğu,
/// tekrar çalıştırılabilirlik ve referans bütünlüğü.
void main() {
  test('bos depoda 278 tarif ve 222 kart eklenir', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();

    final first = await store.importOfficialRecipes();
    expect(first['recipes'], 278);
    expect(first['items'], 222);

    // Ada göre tekillik (büyük/küçük harf duyarsız).
    final names =
        store.inventory.map((e) => e.name.trim().toLowerCase()).toList();
    expect(names.toSet().length, names.length);

    // Her tarif malzemesi gerçek bir stok kartına bağlı.
    for (final r in store.recipes) {
      for (final ing in r.ingredients) {
        expect(store.itemById(ing.itemId) != null, isTrue,
            reason: '${r.name} -> ${ing.itemId}');
      }
    }

    // Nokta kontrol: Düğün Çorba 8 kalem, 1 porsiyonluk.
    final dugun = store.findRecipeByName('Düğün Çorba');
    expect(dugun, isNotNull);
    expect(dugun!.ingredients.length, 8);
    expect(dugun.servingsDefault, 1);

    // İkinci çalıştırma hiçbir şey eklemez.
    final second = await store.importOfficialRecipes();
    expect(second['recipes'], 0);
    expect(second['items'], 0);
    expect(store.recipes.length, 278);
  });

  test('ornek veride ayni adli 5 tarif atlanir', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    store.loadSampleData();

    final first = await store.importOfficialRecipes();
    // Cacık, Menemen, Kısır, Çoban Salata, Etli Nohut örnekte var.
    expect(first['recipes'], 273);
    expect(store.findRecipeByName('Kısır'), isNotNull);
  });
}
