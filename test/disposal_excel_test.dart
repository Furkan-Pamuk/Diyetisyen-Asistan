import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dietitian_flutter/models/disposal.dart';
import 'package:dietitian_flutter/services/disposal_excel.dart';

void main() {
  test('sirket excel formu birebir doldurulur', () async {
    final tpl = await File('assets/imha_tutanak_sablonu.xlsx')
        .readAsBytes();
    final form = DisposalForm(
      docNo: 'SA.08-F.01',
      revNo: '1',
      revDate: DateTime(2026, 10, 18),
      lines: [
        DisposalLine(
          productName: 'Domates',
          unitKey: 'gram',
          quantity: 2500,
          uretimTarihi: DateTime(2026, 10, 10),
          dolapGirisTarihi: DateTime(2026, 10, 11),
          skt: DateTime(2026, 10, 15),
          bozulma: 'Kuf',
          imhaNedeni: 'SKT gecmis',
          tahminiBedel: 150,
        ),
        DisposalLine(
          productName: 'Yumurta',
          unitKey: 'piece',
          quantity: 12,
          imhaNedeni: 'Kirik',
          tahminiBedel: 60,
        ),
      ],
      uygunsuzlukNedenleri: 'Soguk zincir aksadi',
      gerceklesenFaaliyet: 'Urun imha edildi',
      planlananFaaliyet: 'Personel egitimi',
      asciAdi: 'Ali Usta',
      yoneticiAdi: 'Veli Yonetici',
      bolgeAdi: 'Ayse Bolge',
      imzaTarihi: DateTime(2026, 10, 18),
    );

    final out = await buildFilledDisposalExcel(
        templateBytes: tpl, form: form);
    expect(out.isNotEmpty, isTrue);

    // Sonucu excel paketiyle geri oku (hücre haritası doğrulaması).
    final wb = Excel.decodeBytes(out);
    final sheet = wb.tables['Sheet1'] ?? wb.tables.values.first;
    String cell(String ref) {
      // ref örn. "A9" -> col/row
      final col =
          ref.codeUnits.first - 'A'.codeUnits.first;
      final row = int.parse(ref.substring(1)) - 1;
      final v = sheet.rows[row][col]?.value;
      return v?.toString() ?? '';
    }

    expect(cell('M1'), 'SA.08-F.01');
    expect(cell('A9'), 'Domates');
    expect(cell('C9'), '2500');
    expect(cell('A10'), 'Yumurta');
    expect(cell('C10'), '12');
    expect(cell('M9'), 'SKT gecmis');
    expect(cell('A24'), contains('Soguk zincir'));
    expect(cell('E24'), contains('Personel'));
    expect(cell('J24'), contains('imha edildi'));
    // Tarih seri sayıdır.
    expect(double.tryParse(cell('E9')) != null, isTrue);
  });
}
