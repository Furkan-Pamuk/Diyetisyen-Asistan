# Dietitian Assistant — Flutter (Android / iOS / Web)

## Farklı cihazlarda aynı veri (ücretsiz Firebase eşitlemesi)

Veri normalde her cihazın kendi tarayıcısında durur. Aynı hesapla girince
bulutta eşitlenir: telefonda eklediğin liste bilgisayarda görünür.

Kurulum (bir kez yapılır, Mac gerekmez):

1. **Firebase projesi:** console.firebase.google.com → Add project
   (adı örn. `diyetisyen-asistan`, Analytics kapalı olabilir) → Create.
2. **Giriş yöntemi:** sol menü Build → Authentication → Get started →
   Sign-in method → **Email/Password** → Enable → Save.
3. **Veritabanı:** Build → Firestore Database → Create database →
   **Start in production mode** → bölge seç (örn. europe-west) → Enable.
   Rules sekmesine geçip kuralları şununla değiştirip Publish et:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
4. **Bağlantı aracı:**
   ```
   dart pub global activate flutterfire_cli
   ```
5. **Uygulamayı bağla** (proje klasöründe; web seç, hesabını seç,
   Firebase projesini seç):
   ```
   cd dietitian_flutter
   flutterfire configure
   ```
   Bu `lib/firebase_options.dart` dosyasını üretir.
6. **Gönder ve yayınla:**
   ```
   flutter pub get
   flutter analyze
   flutter run -d edge
   ```
   Çalışıyorsa `git add/commit/push` — site otomatik güncellenir.
7. **Kullanım:** telefonda ve bilgisayarda siteye girip **aynı e-postayla**
   kayıt ol/giriş yap. Özet ekranında yeşil bulut = eşitleme açık.
   Son değişiklik kazanır; internetsiz yapılan değişiklikler bağlantı
   gelince eşitlenir. "Hesapsız devam et" dersen veri o cihazda kalır.

Maliyet: Spark (ücretsiz) plan bu kullanıma fazlasıyla yeter.


Flutter port of the dietitian assistant. Same three core features as the SwiftUI version:

1. **Supplier X order reminders** — order/pickup dates, countdowns, local notifications (`flutter_local_notifications`).
   Supplier directory: add/edit/delete suppliers, per-supplier filter on orders.
2. **Dynamic inventory** — warehouse inbound vs recipe-production deductions, low-stock alerts.
   Production supports manual servings (1-10000, e.g. 200 people) and editable ingredient totals.
3. **Weekly grocery list** — deficit = planned need − stock, grouped into **Hal / Kuru Gıda / Et Süt** with precise g / adet.
   Weekly menu program (Mon-Sun, per meal) feeds the grocery list when non-empty.
   Manual product entry with ~110-item Turkish autocomplete suggestions ("m" → Mandalina, Muz...).
4. **Recipes** — 16 sample recipes, full CRUD: add/edit/delete recipes with hand-editable
   per-serving amounts; new stock products can be created inline while defining a recipe.

## Structure

```
lib/
  main.dart                  — entry, Provider<AppStore>, Material 3
  models/
    grocery_category.dart    — GroceryCategory + StockUnit
    inventory_item.dart
    supplier.dart            — supplier directory (name, phone, note)
    supplier_order.dart      — countdowns, AlertLevel, supplierId link
    menu_entry.dart          — weekly menu lines (day, meal, recipe, servings)
    recipe.dart              — Recipe, RecipeIngredient, ProductionLog, WeeklyPlanEntry, GroceryItem
  state/app_store.dart       — ChangeNotifier, produce()/produceCustom(), receiveShipment(),
                               suppliers + menu CRUD, generateGroceryList() (menu-first),
                               SharedPreferences persistence + sample data
  services/notification_service.dart
  widgets/common.dart        — StatusBadge, CountdownText, StockBar, EmptyState
  screens/
    home_screen.dart         — bottom NavigationBar (6 tabs + badges)
    dashboard_screen.dart    — today's menu + alerts + stock + progress
    supplier_orders_screen.dart — supplier filter, orders, supplier directory
    inventory_screen.dart
    recipes_screen.dart      — manual servings + editable ingredient totals
    menu_screen.dart         — weekly menu program (days × meals)
    grocery_list_screen.dart — Share export, menu/plan source note
```

## Run (no Mac needed)

1. Install Flutter SDK (>=3.2): https://docs.flutter.dev/get-started/install/windows
2. `cd dietitian_flutter`
3. If platform folders are missing (this repo ships only `lib/` + `pubspec.yaml`):
   `flutter create --platforms android,ios,web .`
4. `flutter pub get`
5. `flutter run` (Android emulator / Chrome: `flutter run -d chrome`)

## Upload to GitHub

```powershell
cd C:\Users\furka\Desktop\Projects\Diet\dietitian_flutter
git init
git add .
git commit -m "Dietitian assistant Flutter app"
gh repo create dietitian-flutter --public --source=. --push
# without gh CLI:
# git remote add origin https://github.com/<you>/dietitian-flutter.git
# git branch -M main
# git push -u origin main
```

Then open the GitHub repo in any Flutter-capable environment (VS Code + Flutter extension) and press F5.

## Notes

- Sample Turkish dataset ships on first launch (same as SwiftUI version).
- Data persists via SharedPreferences key `dietitian-assistant-v1`. Clear app data to reset.
- Notifications on Android need no extra setup; on iOS accept the permission prompt.
- The old SwiftUI prototype is kept in `../DietitianAssistant/` for reference.
