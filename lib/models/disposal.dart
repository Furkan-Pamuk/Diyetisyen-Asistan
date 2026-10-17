import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// İmha tutanağı şablonu (bir kez oluşturulur): formlara
/// varsayılan gelen doküman bilgileri ve imza isimleri.
class DisposalTemplate {
  String docNo;
  String revNo;
  DateTime? revDate;
  String asciAdi; // Aşçıbaşı / Sorumlu
  String yoneticiAdi; // İşletme Yöneticisi
  String bolgeAdi; // Bölge Müdürü
  String defaultImhaNedeni;
  String defaultUygunsuzluk;

  DisposalTemplate({
    this.docNo = 'SA.08-F.01',
    this.revNo = '0',
    this.revDate,
    this.asciAdi = '',
    this.yoneticiAdi = '',
    this.bolgeAdi = '',
    this.defaultImhaNedeni = '',
    this.defaultUygunsuzluk = '',
  });

  factory DisposalTemplate.fromJson(Map<String, dynamic> j) =>
      DisposalTemplate(
        docNo: (j['docNo'] as String?) ?? 'SA.08-F.01',
        revNo: (j['revNo'] as String?) ?? '0',
        revDate: j['revDate'] == null
            ? null
            : DateTime.tryParse(j['revDate'] as String),
        asciAdi: (j['asciAdi'] as String?) ?? '',
        yoneticiAdi: (j['yoneticiAdi'] as String?) ?? '',
        bolgeAdi: (j['bolgeAdi'] as String?) ?? '',
        defaultImhaNedeni:
            (j['defaultImhaNedeni'] as String?) ?? '',
        defaultUygunsuzluk:
            (j['defaultUygunsuzluk'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'docNo': docNo,
        'revNo': revNo,
        'revDate': revDate?.toIso8601String(),
        'asciAdi': asciAdi,
        'yoneticiAdi': yoneticiAdi,
        'bolgeAdi': bolgeAdi,
        'defaultImhaNedeni': defaultImhaNedeni,
        'defaultUygunsuzluk': defaultUygunsuzluk,
      };
}

/// Tutanağın tek ürün satırı (Excel'deki tablo satırları).
class DisposalLine {
  String productName;
  String? itemId; // stokla eşleşirse
  String unitKey; // 'gram' | 'piece'
  double quantity;
  DateTime? uretimTarihi;
  DateTime? dolapGirisTarihi; // stok partisinden otomatik
  DateTime? skt;
  String bozulma; // "Bozulma varsa, nedir?"
  String imhaNedeni;
  double tahminiBedel;

  DisposalLine({
    this.productName = '',
    this.itemId,
    this.unitKey = 'gram',
    this.quantity = 0,
    this.uretimTarihi,
    this.dolapGirisTarihi,
    this.skt,
    this.bozulma = '',
    this.imhaNedeni = '',
    this.tahminiBedel = 0,
  });

  /// SKT bugünden geçmişse kaç gün geçti (geçmediyse 0).
  int get sktGunFarki {
    if (skt == null) return 0;
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(skt!.year, skt!.month, skt!.day);
    final d = a.difference(b).inDays;
    return d > 0 ? d : 0;
  }

  factory DisposalLine.fromJson(Map<String, dynamic> j) =>
      DisposalLine(
        productName: (j['productName'] as String?) ?? '',
        itemId: j['itemId'] as String?,
        unitKey: (j['unit'] as String?) ?? 'gram',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
        uretimTarihi: j['uretimTarihi'] == null
            ? null
            : DateTime.tryParse(j['uretimTarihi'] as String),
        dolapGirisTarihi: j['dolapGirisTarihi'] == null
            ? null
            : DateTime.tryParse(
                j['dolapGirisTarihi'] as String),
        skt: j['skt'] == null
            ? null
            : DateTime.tryParse(j['skt'] as String),
        bozulma: (j['bozulma'] as String?) ?? '',
        imhaNedeni: (j['imhaNedeni'] as String?) ?? '',
        tahminiBedel:
            (j['tahminiBedel'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'itemId': itemId,
        'unit': unitKey,
        'quantity': quantity,
        'uretimTarihi': uretimTarihi?.toIso8601String(),
        'dolapGirisTarihi': dolapGirisTarihi?.toIso8601String(),
        'skt': skt?.toIso8601String(),
        'bozulma': bozulma,
        'imhaNedeni': imhaNedeni,
        'tahminiBedel': tahminiBedel,
      };
}

/// Doldurulmuş imha tutanağı (şablondan üretilir, arşivde saklanır).
class DisposalForm {
  final String id;
  DateTime createdAt;
  String docNo;
  String revNo;
  DateTime? revDate;
  List<DisposalLine> lines;
  String uygunsuzlukNedenleri;
  String gerceklesenFaaliyet;
  String planlananFaaliyet;
  String asciAdi;
  String yoneticiAdi;
  String bolgeAdi;
  DateTime? imzaTarihi;
  bool stockDeducted;

  DisposalForm({
    String? id,
    DateTime? createdAt,
    required this.docNo,
    required this.revNo,
    this.revDate,
    required this.lines,
    this.uygunsuzlukNedenleri = '',
    this.gerceklesenFaaliyet = '',
    this.planlananFaaliyet = '',
    this.asciAdi = '',
    this.yoneticiAdi = '',
    this.bolgeAdi = '',
    this.imzaTarihi,
    this.stockDeducted = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory DisposalForm.fromTemplate(DisposalTemplate t) =>
      DisposalForm(
        docNo: t.docNo,
        revNo: t.revNo,
        revDate: t.revDate,
        lines: [],
        uygunsuzlukNedenleri: t.defaultUygunsuzluk,
        asciAdi: t.asciAdi,
        yoneticiAdi: t.yoneticiAdi,
        bolgeAdi: t.bolgeAdi,
      );

  double get toplamBedel =>
      lines.fold(0, (s, l) => s + l.tahminiBedel);

  factory DisposalForm.fromJson(Map<String, dynamic> j) =>
      DisposalForm(
        id: j['id'] as String?,
        createdAt: DateTime.tryParse(
                j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        docNo: (j['docNo'] as String?) ?? 'SA.08-F.01',
        revNo: (j['revNo'] as String?) ?? '0',
        revDate: j['revDate'] == null
            ? null
            : DateTime.tryParse(j['revDate'] as String),
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => DisposalLine.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        uygunsuzlukNedenleri:
            (j['uygunsuzlukNedenleri'] as String?) ?? '',
        gerceklesenFaaliyet:
            (j['gerceklesenFaaliyet'] as String?) ?? '',
        planlananFaaliyet:
            (j['planlananFaaliyet'] as String?) ?? '',
        asciAdi: (j['asciAdi'] as String?) ?? '',
        yoneticiAdi: (j['yoneticiAdi'] as String?) ?? '',
        bolgeAdi: (j['bolgeAdi'] as String?) ?? '',
        imzaTarihi: j['imzaTarihi'] == null
            ? null
            : DateTime.tryParse(j['imzaTarihi'] as String),
        stockDeducted: (j['stockDeducted'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'docNo': docNo,
        'revNo': revNo,
        'revDate': revDate?.toIso8601String(),
        'lines': lines.map((e) => e.toJson()).toList(),
        'uygunsuzlukNedenleri': uygunsuzlukNedenleri,
        'gerceklesenFaaliyet': gerceklesenFaaliyet,
        'planlananFaaliyet': planlananFaaliyet,
        'asciAdi': asciAdi,
        'yoneticiAdi': yoneticiAdi,
        'bolgeAdi': bolgeAdi,
        'imzaTarihi': imzaTarihi?.toIso8601String(),
        'stockDeducted': stockDeducted,
      };
}
