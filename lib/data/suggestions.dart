import '../models/grocery_category.dart';

/// Searchable Turkish product database used for autocomplete when the user
/// types a product name (grocery add, inventory add, recipe ingredients).
class SuggestedProduct {
  final String name;
  final GroceryCategory category;
  final StockUnit unit;

  const SuggestedProduct(this.name, this.category, this.unit);
}

const suggestedProducts = <SuggestedProduct>[
  // ---------- Fresh Produce / Hal (gram) ----------
  SuggestedProduct('Domates', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Salatalık', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Patates', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Soğan', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Havuç', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Biber', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Patlıcan', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Kabak', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Ispanak', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Maydanoz', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Dereotu', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Taze Nane', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Roka', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Marul', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Lahana', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Karnabahar', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Brokoli', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Pırasa', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Kereviz', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Turp', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Pancar', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Mantar', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Taze Fasulye', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Bezelye', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Bamya', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Enginar', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Semizotu', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Tere', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Sarımsak', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Taze Soğan', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Mısır', GroceryCategory.freshProduce, StockUnit.piece),
  // ---------- Fresh Produce / Hal (piece) ----------
  SuggestedProduct('Elma', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Muz', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Mandalina', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Portakal', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Armut', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Ayva', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Nar', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Üzüm', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Karpuz', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Kavun', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Kivi', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Ananas', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Avokado', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Şeftali', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Kayısı', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Kiraz', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Vişne', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Çilek', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Erik', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('İncir', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Hurma', GroceryCategory.freshProduce, StockUnit.gram),
  SuggestedProduct('Limon', GroceryCategory.freshProduce, StockUnit.piece),
  SuggestedProduct('Greyfurt', GroceryCategory.freshProduce, StockUnit.piece),
  // ---------- Dry Goods / Kuru Gıda ----------
  SuggestedProduct('Kırmızı Mercimek', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Yeşil Mercimek', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Pirinç', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Bulgur', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Nohut', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kuru Fasulye', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Barbunya', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Börülce', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Yulaf', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Un', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Makarna', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Şehriye', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Tarhana', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kuskus', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('İrmik', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Mısır Unu', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Nişasta', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Toz Şeker', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Tuz', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Karabiber', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kimyon', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Pul Biber', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kekik', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kuru Nane', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Tarçın', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Çay', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Türk Kahvesi', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Filtre Kahve', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Kakao', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Zeytinyağı', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Ayçiçek Yağı', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Sirke', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Domates Salçası', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Biber Salçası', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Bal', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Pekmez', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Tahin', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Reçel', GroceryCategory.dryGoods, StockUnit.gram),
  SuggestedProduct('Ton Balığı', GroceryCategory.dryGoods, StockUnit.piece),
  SuggestedProduct('Mısır Konservesi', GroceryCategory.dryGoods, StockUnit.piece),
  // ---------- Meat & Dairy / Et Süt ----------
  SuggestedProduct('Tavuk Göğsü', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Tavuk But', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Tavuk Kanat', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Kıyma', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Kuşbaşı Et', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Levrek', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Hamsi', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Yoğurt', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Süt', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Beyaz Peynir', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Kaşar Peyniri', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Tereyağı', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Krem Peynir', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Lor Peyniri', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Ayran', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Kefir', GroceryCategory.meatDairy, StockUnit.gram),
  SuggestedProduct('Yumurta', GroceryCategory.meatDairy, StockUnit.piece),
];

/// Case-insensitive search over the database ("m" -> Mandalina, Muz...).
List<SuggestedProduct> searchSuggestions(String query, {int limit = 12}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return suggestedProducts.take(8).toList();
  final starts = <SuggestedProduct>[];
  final contains = <SuggestedProduct>[];
  for (final p in suggestedProducts) {
    final name = p.name.toLowerCase();
    if (name.startsWith(q)) {
      starts.add(p);
    } else if (name.contains(q)) {
      contains.add(p);
    }
    if (starts.length >= limit) break;
  }
  return [...starts, ...contains].take(limit).toList();
}

/// Exact (case-insensitive) match, used to auto-fill category/unit.
SuggestedProduct? exactSuggestion(String name) {
  final q = name.trim().toLowerCase();
  if (q.isEmpty) return null;
  try {
    return suggestedProducts
        .firstWhere((p) => p.name.toLowerCase() == q);
  } catch (_) {
    return null;
  }
}
