import 'package:flutter_test/flutter_test.dart';

import 'package:dietitian_flutter/services/pdf_service.dart';

/// Paylaş/yazdır altyapısı: PDF üreteçleri boş dönmemeli,
/// metin paylaşımı başlık ve kalemleri içermeli.
void main() {
  test('reçete PDF baytı üretilir', () async {
    final bytes = await PdfService.buildRecipePdf(
      title: 'Düğün Çorba',
      subtitle: '1 porsiyon',
      items: const [
        {'name': 'Dana Eti', 'qty': '10 g / kişi'},
        {'name': 'Un', 'qty': '5 g / kişi'},
      ],
    );
    expect(bytes.isNotEmpty, isTrue);
  });

  test('haftalık menü PDF baytı üretilir', () async {
    final bytes = await PdfService.buildWeekMenuPdf(
      weekLabel: '1. Hafta',
      groups: const {
        'Pazartesi': [
          {'name': 'Öğle: Mercimek Çorba', 'qty': '50 kişi'},
        ],
      },
    );
    expect(bytes.isNotEmpty, isTrue);
  });

  test('haftalık üretim toplamı PDF baytı üretilir', () async {
    final bytes = await PdfService.buildWeekTotalsPdf(
      weekLabel: '1. Hafta',
      servingsLine: 'Pzt 50',
      items: const [
        {'name': 'Domates', 'qty': '2500 g'},
      ],
    );
    expect(bytes.isNotEmpty, isTrue);
  });

  test('reçete metni başlık ve kalem içerir', () {
    final text = PdfService.recipeShareText(
      title: 'Düğün Çorba',
      subtitle: '1 porsiyon',
      items: const [
        {'name': 'Dana Eti', 'qty': '10 g / kişi'},
      ],
    );
    expect(text.contains('Düğün Çorba'), isTrue);
    expect(text.contains('Dana Eti'), isTrue);
    expect(text.contains('10 g / kişi'), isTrue);
  });
}
