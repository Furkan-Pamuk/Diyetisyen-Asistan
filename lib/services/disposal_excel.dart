import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/disposal.dart';

/// Şirket Excel formunu (SA.08-F.01) BİREBİR koruyarak doldurur.
///
/// Yöntem: şablon .xlsx'in ZIP'i açılır, yalnızca hücre DEĞERLERİ
/// (sheet1.xml + sharedStrings.xml) değiştirilir; birleştirmeler,
/// stiller, logo ve yazdırma ayarları aynen kalır.
/// Hücre haritası (şablondan çıkarıldı):
/// M1 doküman no, M2 revizyon tarihi, M3 revizyon no,
/// satırlar 9-15: A ürün, C miktar, D bedel, E üretim trh,
/// G dolap giriş, I SKT, K gün/bozulma, M imha nedeni;
/// A24 uygunsuzluk, E24 planlanan faaliyet, J24 gerçekleşen faaliyet,
/// A16 imza paragrafına isimler eklenir.
Future<Uint8List> buildFilledDisposalExcel({
  required Uint8List templateBytes,
  required DisposalForm form,
}) async {
  final archive = ZipDecoder().decodeBytes(templateBytes);

  ArchiveFile fileOf(String name) {
    try {
      return archive.files.firstWhere((f) => f.name == name);
    } catch (_) {
      throw StateError('Sablon bozuk: $name yok');
    }
  }

  final sheetFile = fileOf('xl/worksheets/sheet1.xml');
  final ssFile = fileOf('xl/sharedStrings.xml');
  final sheet =
      XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
  final ssDoc =
      XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
  final sst = ssDoc.rootElement;

  int uniqueCount =
      int.tryParse(sst.getAttribute('uniqueCount') ?? '') ?? 0;
  int count = int.tryParse(sst.getAttribute('count') ?? '') ?? 0;
  final existing = <String, int>{};
  var idx = 0;
  for (final si in sst.findElements('si')) {
    existing[_siText(si)] = idx;
    idx++;
  }
  // sharedStrings'e ekler, indeks döner (aynı metin tekrar kullanılır).
  int addString(String text) {
    final hit = existing[text];
    count++;
    sst.setAttribute('count', '$count');
    if (hit != null) return hit;
    final si = XmlElement(XmlName('si'), [], [
      XmlElement(XmlName('t'), [], [XmlText(text)]),
    ]);
    sst.children.add(si);
    existing[text] = uniqueCount;
    uniqueCount++;
    sst.setAttribute('uniqueCount', '$uniqueCount');
    return uniqueCount - 1;
  }

  final sheetData =
      sheet.rootElement.findElements('sheetData').first;

  XmlElement? findRow(String r) {
    for (final row in sheetData.findElements('row')) {
      if (row.getAttribute('r') == r) return row;
    }
    return null;
  }

  XmlElement? findCell(XmlElement row, String ref) {
    for (final c in row.findElements('c')) {
      if (c.getAttribute('r') == ref) return c;
    }
    return null;
  }

  XmlElement ensureCell(XmlElement row, String ref) {
    final c = findCell(row, ref);
    if (c != null) return c;
    final created =
        XmlElement(XmlName('c'), [XmlAttribute(XmlName('r'), ref)]);
    row.children.add(created);
    return created;
  }

  void setShared(String rowRef, String cellRef, String text) {
    if (text.isEmpty) return;
    final row = findRow(rowRef);
    if (row == null) return;
    final c = ensureCell(row, cellRef);
    final sIdx = addString(text);
    c.setAttribute('t', 's');
    c.children
      ..clear()
      ..add(XmlElement(XmlName('v'), [], [XmlText('$sIdx')]));
  }

  void setNumber(String rowRef, String cellRef, num value) {
    final row = findRow(rowRef);
    if (row == null) return;
    final c = ensureCell(row, cellRef);
    c.removeAttribute('t');
    final text = value is int || value == value.roundToDouble()
        ? '${value.round()}'
        : '$value';
    c.children
      ..clear()
      ..add(XmlElement(XmlName('v'), [], [XmlText(text)]));
  }

  int serial(DateTime d) =>
      DateTime(d.year, d.month, d.day)
          .difference(DateTime(1899, 12, 30))
          .inDays;

  // ---- Başlık ----
  setShared('1', 'M1', form.docNo);
  if (form.revDate != null) setNumber('2', 'M2', serial(form.revDate!));
  final revNo = num.tryParse(form.revNo);
  if (revNo != null) {
    setNumber('3', 'M3', revNo);
  } else if (form.revNo.isNotEmpty) {
    setShared('3', 'M3', form.revNo);
  }

  // ---- Ürün satırları (şablonda 9-15, en fazla 7 satır) ----
  final lines = form.lines.take(7).toList();
  for (var i = 0; i < lines.length; i++) {
    final r = '${9 + i}';
    final l = lines[i];
    setShared(r, 'A$r', l.productName);
    if (l.quantity != 0) setNumber(r, 'C$r', l.quantity);
    if (l.tahminiBedel != 0) {
      setNumber(r, 'D$r', l.tahminiBedel);
    }
    if (l.uretimTarihi != null) {
      setNumber(r, 'E$r', serial(l.uretimTarihi!));
    }
    if (l.dolapGirisTarihi != null) {
      setNumber(r, 'G$r', serial(l.dolapGirisTarihi!));
    }
    if (l.skt != null) setNumber(r, 'I$r', serial(l.skt!));
    final gunNote = l.sktGunFarki > 0 ? '${l.sktGunFarki} gün' : '';
    final kText = [
      if (gunNote.isNotEmpty) gunNote,
      if (l.bozulma.trim().isNotEmpty) l.bozulma.trim(),
    ].join(' - ');
    if (kText.isNotEmpty) setShared(r, 'K$r', kText);
    setShared(r, 'M$r', l.imhaNedeni);
  }

  // ---- Bölüm alanları (birleştirilmiş alanların sol üst hücresi) ----
  if (form.uygunsuzlukNedenleri.trim().isNotEmpty) {
    setShared('24', 'A24', form.uygunsuzlukNedenleri.trim());
  }
  if (form.planlananFaaliyet.trim().isNotEmpty) {
    setShared('24', 'E24', form.planlananFaaliyet.trim());
  }
  if (form.gerceklesenFaaliyet.trim().isNotEmpty) {
    setShared('24', 'J24', form.gerceklesenFaaliyet.trim());
  }

  // ---- İmza paragrafına isimler (orijinal metin korunarak eklenir) ----
  final sigParts = [
    if (form.asciAdi.trim().isNotEmpty)
      'Aşçıbaşı / Sorumlu: ${form.asciAdi.trim()}',
    if (form.yoneticiAdi.trim().isNotEmpty)
      'İşletme Yöneticisi: ${form.yoneticiAdi.trim()}',
    if (form.bolgeAdi.trim().isNotEmpty)
      'Bölge Müdürü: ${form.bolgeAdi.trim()}',
    if (form.imzaTarihi != null)
      'Tarih: ${_d(form.imzaTarihi!)}',
  ];
  if (sigParts.isNotEmpty) {
    final row16 = findRow('16');
    final a16 = row16 == null ? null : findCell(row16, 'A16');
    if (a16 != null && a16.getAttribute('t') == 's') {
      final oldIdx = int.tryParse(
          a16.findElements('v').firstOrNull?.innerText ?? '');
      String old = '';
      if (oldIdx != null) {
        final sis = sst.findElements('si').toList();
        if (oldIdx >= 0 && oldIdx < sis.length) {
          old = _siText(sis[oldIdx]);
        }
      }
      final combined = '$old\n${sigParts.join(' | ')}';
      final sIdx = addString(combined);
      a16.children
        ..clear()
        ..add(XmlElement(XmlName('v'), [], [XmlText('$sIdx')]));
    }
  }

  // ---- Geri yaz (aynı ZIP girdileri, yalnızca 2 dosya değişir) ----
  final fresh = <String, Uint8List>{
    'xl/worksheets/sheet1.xml': Uint8List.fromList(
        utf8.encode(sheet.toXmlString(pretty: false))),
    'xl/sharedStrings.xml': Uint8List.fromList(
        utf8.encode(ssDoc.toXmlString(pretty: false))),
  };
  final rebuilt = Archive();
  for (final f in archive.files) {
    if (fresh.containsKey(f.name)) {
      final data = fresh[f.name]!;
      rebuilt.addFile(ArchiveFile(f.name, data.length, data));
    } else {
      rebuilt.addFile(f);
    }
  }
  final out = ZipEncoder().encode(rebuilt);
  if (out == null) throw StateError('Excel yazılamadı');
  return Uint8List.fromList(out);
}

String _siText(XmlElement si) {
  final buf = StringBuffer();
  for (final t in si.findAllElements('t')) {
    buf.write(t.innerText);
  }
  return buf.toString();
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

extension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final e in this) {
      return e;
    }
    return null;
  }
}
