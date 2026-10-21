import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/grocery_category.dart';

/// Liste PDF'leri: sepet, alışveriş listesi, haftalık üretim toplamı.
/// `share*` çağrıları mobilde paylaşım sayfası, web'de indirme açar.
///
/// Not: gömülü Helvetica Türkçe karakterleri (ğ, ş, ı, İ) desteklemez;
/// bu yüzden tüm metinler ASCII'ye çevrilir (örn. "Kırmızı" -> "Kirmizi").
class PdfService {
  PdfService._();

  static String tr(String s) => s
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'G')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 'S')
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'I')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'C')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'O')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'U')
      .replaceAll('•', '-')
      .replaceAll('✓', 'x');

  static pw.Widget _header(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(tr(title),
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(tr(subtitle),
            style: const pw.TextStyle(
                fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _row(String left, String right, {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: 11,
        fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(tr(left), style: style)),
          pw.Text(tr(right), style: style),
        ],
      ),
    );
  }

  static String fmtQty(double v, String unitKey) =>
      StockUnitX.fromKey(unitKey).format(v);

  static String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Sepet PDF'i, tedarikçi gruplarıyla.
  static Future<void> shareCartPdf({
    required Map<String, List<Map<String, String>>> groups,
    // groupTitle -> [{name, qty}]
    required String filename,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header('Siparis Sepeti', fmtDate(DateTime.now())),
        for (final g in groups.entries) ...[
          pw.SizedBox(height: 6),
          pw.Text(tr(g.key),
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          for (final item in g.value)
            _row(item['name']!, item['qty']!),
        ],
      ],
    ));
    await Printing.sharePdf(
        bytes: await doc.save(), filename: filename);
  }

  /// Alışveriş listesi PDF'i, kategori başlıklarıyla.
  static Future<void> shareGroceryPdf({
    required String weekLabel,
    required Map<String, List<Map<String, String>>> groups,
    // categoryTitle -> [{name, qty, stock}]
    required String filename,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header('Haftalik Alisveris Listesi',
            '$weekLabel • ${fmtDate(DateTime.now())}'),
        for (final g in groups.entries) ...[
          pw.SizedBox(height: 6),
          pw.Text(tr(g.key),
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          for (final item in g.value)
            _row(item['name']!, item['qty']!),
        ],
      ],
    ));
    await Printing.sharePdf(
        bytes: await doc.save(), filename: filename);
  }

  /// Haftalık üretim toplamı PDF'i (günlük kişi sayıları + toplamlar).
  static Future<Uint8List> buildWeekTotalsPdf({
    required String weekLabel,
    required String servingsLine,
    required List<Map<String, String>> items,
    // [{name, qty}]
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header('Haftalik Uretim Toplami',
            '$weekLabel • $servingsLine • ${fmtDate(DateTime.now())}'),
        for (final item in items)
          _row(item['name']!, item['qty']!),
      ],
    ));
    return doc.save();
  }

  static Future<void> shareWeekTotalsPdf({
    required String weekLabel,
    required String servingsLine,
    required List<Map<String, String>> items,
    required String filename,
  }) async {
    await Printing.sharePdf(
        bytes: await buildWeekTotalsPdf(
            weekLabel: weekLabel,
            servingsLine: servingsLine,
            items: items),
        filename: filename);
  }

  static Future<void> printWeekTotalsPdf({
    required String weekLabel,
    required String servingsLine,
    required List<Map<String, String>> items,
    required String filename,
  }) async {
    final bytes = await buildWeekTotalsPdf(
        weekLabel: weekLabel,
        servingsLine: servingsLine,
        items: items);
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: filename);
  }

  /// Haftalık menü PDF'i (gün gün öğünler).
  static Future<Uint8List> buildWeekMenuPdf({
    required String weekLabel,
    required Map<String, List<Map<String, String>>> groups,
    // dayTitle -> [{name: 'Öğle: Mercimek Çorba', qty: '50 kişi'}]
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header('Haftalik Menu',
            '$weekLabel • ${fmtDate(DateTime.now())}'),
        for (final g in groups.entries) ...[
          pw.SizedBox(height: 6),
          pw.Text(tr(g.key),
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          for (final item in g.value)
            _row(item['name']!, item['qty']!),
        ],
      ],
    ));
    return doc.save();
  }

  static Future<void> shareWeekMenuPdf({
    required String weekLabel,
    required Map<String, List<Map<String, String>>> groups,
    required String filename,
  }) async {
    await Printing.sharePdf(
        bytes: await buildWeekMenuPdf(
            weekLabel: weekLabel, groups: groups),
        filename: filename);
  }

  static Future<void> printWeekMenuPdf({
    required String weekLabel,
    required Map<String, List<Map<String, String>>> groups,
    required String filename,
  }) async {
    final bytes = await buildWeekMenuPdf(
        weekLabel: weekLabel, groups: groups);
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: filename);
  }

  /// Tek reçete/tarif PDF'i.
  static Future<Uint8List> buildRecipePdf({
    required String title,
    required String subtitle,
    required List<Map<String, String>> items,
    // [{name, qty}]
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        _header(title, subtitle),
        for (final item in items)
          _row(item['name']!, item['qty']!),
      ],
    ));
    return doc.save();
  }

  static Future<void> shareRecipePdf({
    required String title,
    required String subtitle,
    required List<Map<String, String>> items,
    required String filename,
  }) async {
    await Printing.sharePdf(
        bytes: await buildRecipePdf(
            title: title, subtitle: subtitle, items: items),
        filename: filename);
  }

  static Future<void> printRecipePdf({
    required String title,
    required String subtitle,
    required List<Map<String, String>> items,
    required String filename,
  }) async {
    final bytes = await buildRecipePdf(
        title: title, subtitle: subtitle, items: items);
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: filename);
  }

  /// Reçete/tarif metin paylaşımı (WhatsApp vb.).
  static String recipeShareText({
    required String title,
    required String subtitle,
    required List<Map<String, String>> items,
  }) {
    final buf = StringBuffer('$title\n$subtitle\n\n');
    for (final item in items) {
      buf.writeln('• ${item['name']}: ${item['qty']}');
    }
    return buf.toString();
  }

  /// İmha tutanağı PDF'i (Excel form düzeninde).
  static Future<void> shareDisposalPdf({
    required Map<String, String?> header,
    // docNo, revNo, revDate, createdAt
    required List<Map<String, String>> lines,
    // [{urun, miktar, uretim, giris, skt, gun, bozulma, neden, bedel}]
    required Map<String, String> sections,
    // uygunsuzluk, gerceklesen, planlanan, asci, yonetici, bolge, imzaTarihi, toplam
    required String filename,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Center(
          child: pw.Text('IMHA TUTANAK FORMU',
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Dokuman No: ${header['docNo'] ?? ''}",
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
                "Revizyon: ${header['revNo'] ?? ''} (${header['revDate'] ?? ''})",
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Tarih: ${header['createdAt'] ?? ''}",
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.1),
            3: const pw.FlexColumnWidth(1.1),
            4: const pw.FlexColumnWidth(1.1),
            5: const pw.FlexColumnWidth(0.8),
            6: const pw.FlexColumnWidth(1.6),
            7: const pw.FlexColumnWidth(1.6),
            8: const pw.FlexColumnWidth(0.9),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300),
              children: [
                for (final h in [
                  'Urun Adi',
                  'Miktar',
                  'Uretim Trh',
                  'Dolap Giris',
                  'SKT',
                  'Gun',
                  'Bozulma',
                  'Imha Nedeni',
                  'Bedel'
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(tr(h),
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold)),
                  ),
              ],
            ),
            for (final l in lines)
              pw.TableRow(children: [
                for (final k in [
                  'urun',
                  'miktar',
                  'uretim',
                  'giris',
                  'skt',
                  'gun',
                  'bozulma',
                  'neden',
                  'bedel'
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(tr(l[k] ?? ''),
                        style:
                            const pw.TextStyle(fontSize: 8)),
                  ),
              ]),
          ],
        ),
        pw.SizedBox(height: 6),
        _row('Uygunsuzlugun Nedenleri:',
            sections['uygunsuzluk'] ?? ''),
        _row('Gerceklesen Duzeltici Faaliyet:',
            sections['gerceklesen'] ?? ''),
        _row('Planlanan Duzeltici Faaliyet:',
            sections['planlanan'] ?? ''),
        _row('Toplam Tahmini Bedel:',
            sections['toplam'] ?? ''),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            for (final s in [
              'Asci / Sorumlu\n${sections['asci'] ?? ''}',
              'Isletme Yoneticisi\n${sections['yonetici'] ?? ''}',
              'Bolge Muduru\n${sections['bolge'] ?? ''}',
            ])
              pw.Column(children: [
                pw.Text(tr(s),
                    textAlign: pw.TextAlign.center,
                    style:
                        const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 18),
                pw.Text(
                    'Imza / ${sections['imzaTarihi'] ?? ''}',
                    style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600)),
              ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
            'Not: Duzeltici faaliyet gerceklestikten sonra Gerceklesen Duzeltici Faaliyet bolumunu doldurarak HKG Departmanina iletiniz.',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600)),
      ],
    ));
    await Printing.sharePdf(
        bytes: await doc.save(), filename: filename);
  }
}
