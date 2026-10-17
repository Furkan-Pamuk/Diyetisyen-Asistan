import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

const _quotes = [
  'Küçük adımlar, büyük değişimler getirir. Bugün de dengeli beslen!',
  'Su içmeyi unutma — günün en kolay sağlıklı alışkanlığı.',
  'Mükemmel öğün değil, sürdürülebilir düzen kazandırır.',
  'Tabağının yarısı sebze olsun, gerisi kendiliğinden gelir.',
  'Her üretim günü, danışanlarına verdiğin sözdür. Stokların hazır olsun!',
  'Yorgunluk çoğu zaman susuzluktur — önce bir bardak su.',
  'Planlı menü, plansız atıştırmalığı yener.',
  'Kendine de danışanlarına gösterdiğin şefkati göster.',
  'Bugün attığın her sağlıklı adım, yarının enerjisi.',
  'Ölç, planla, üret — disiplin motivasyondan güçlüdür.',
];

/// Paneldeki motivasyon kutusu: her 10 saniyede söz değişir ve
/// pembeli patenci kız kutunun üstünden dans ederek kayar.
class MotivationCard extends StatefulWidget {
  const MotivationCard({super.key});

  @override
  State<MotivationCard> createState() => _MotivationCardState();
}

class _MotivationCardState extends State<MotivationCard>
    with SingleTickerProviderStateMixin {
  int _quote = 0;
  bool _gliding = false;
  late final AnimationController _glide;
  Timer? _timer;

  static const _interval = Duration(seconds: 10);
  static const _glideTime = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: _glideTime);
    _glide.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _gliding = false);
      }
    });
    // İlk kayış kısa süre sonra başlasın, sonra her 10 sn'de bir.
    _timer = Timer(const Duration(seconds: 2), _nextRound);
  }

  void _nextRound() {
    if (!mounted) return;
    setState(() {
      _quote = (_quote + 1) % _quotes.length;
      _gliding = true;
    });
    _glide.forward(from: 0);
    _timer = Timer(_interval, _nextRound);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF2F6), Color(0xFFFCE7F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C6DA)),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kayma şeridi (patenci kız buradan geçer)
          SizedBox(
            height: 66,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                if (!_gliding) {
                  return const SizedBox.expand();
                }
                return AnimatedBuilder(
                  animation: _glide,
                  builder: (_, __) {
                    final t = _glide.value;
                    final dx = -70 + t * (w + 150);
                    final hop =
                        -7 * math.sin(math.pi * t).abs();
                    final sway =
                        0.10 * math.sin(2 * math.pi * 2 * t);
                    return Stack(
                      children: [
                        Positioned(
                          left: dx,
                          top: 6 + hop,
                          child: Transform.rotate(
                            angle: sway,
                            child: const CustomPaint(
                              size: Size(58, 58),
                              painter: _SkaterGirlPainter(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 16, color: Color(0xFFD6336C)),
              ),
              const SizedBox(width: 8),
              Text(
                'GÜNÜN MOTİVASYONU',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: const Color(0xFFD6336C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _quotes[_quote],
              key: ValueKey(_quote),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pembeli patenci kız: pembe elbise, açık kollar (dans), patenler.
class _SkaterGirlPainter extends CustomPainter {
  const _SkaterGirlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pink = Paint()..color = const Color(0xFFF06595);
    final pinkLight = Paint()..color = const Color(0xFFF8BBD0);
    final pinkDark = Paint()..color = const Color(0xFFD6336C);
    final skin = Paint()..color = const Color(0xFFFFDDBB);
    final hair = Paint()..color = const Color(0xFF6B4226);
    final white = Paint()..color = Colors.white;

    // Gölge
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height - 3),
          width: 34,
          height: 7),
      Paint()..color = Colors.pink.shade100,
    );

    // Hareket çizgileri (arkada)
    final motion = Paint()
      ..color = const Color(0xFFF8BBD0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(-14, 30, 22, 10), 0.4, 1.6,
        false, motion);
    canvas.drawArc(const Rect.fromLTWH(-10, 38, 18, 8), 0.4, 1.6,
        false, motion);

    // Bacaklar (hafif açık, kayma pozu)
    final leg = Paint()
      ..color = const Color(0xFFFFDDBB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    // arka bacak
    canvas.drawLine(
        const Offset(26, 38), const Offset(19, 50), leg);
    // ön bacak
    canvas.drawLine(
        const Offset(30, 38), const Offset(36, 50), leg);

    // Patenler (pembe bot + tekerlekler)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, 48, 10, 5),
          const Radius.circular(2.5)),
      pinkDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(33, 48, 10, 5),
          const Radius.circular(2.5)),
      pinkDark,
    );
    canvas.drawCircle(const Offset(16, 55), 1.8, white);
    canvas.drawCircle(const Offset(21, 55), 1.8, white);
    canvas.drawCircle(const Offset(36, 55), 1.8, white);
    canvas.drawCircle(const Offset(41, 55), 1.8, white);

    // Etek (kloş pembe)
    final skirt = Path()
      ..moveTo(28, 26)
      ..quadraticBezierTo(20, 34, 16, 40)
      ..quadraticBezierTo(28, 43, 40, 40)
      ..quadraticBezierTo(36, 34, 30, 26)
      ..close();
    canvas.drawPath(skirt, pink);
    // Etek ışıltısı
    final shine = Path()
      ..moveTo(28, 27)
      ..quadraticBezierTo(24, 33, 22, 38)
      ..quadraticBezierTo(27, 39.5, 32, 38)
      ..quadraticBezierTo(30, 33, 29, 27)
      ..close();
    canvas.drawPath(shine, pinkLight);

    // Gövde
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(25.5, 18, 7, 10),
          const Radius.circular(3)),
      pinkDark,
    );

    // Kollar (dans: biri yukarı, biri yana)
    final arm = Paint()
      ..color = const Color(0xFFFFDDBB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(27, 20), const Offset(18, 12), arm);
    canvas.drawLine(
        const Offset(31, 20), const Offset(41, 17), arm);
    // El süsleri
    canvas.drawCircle(const Offset(18, 12), 2.2, pinkLight);
    canvas.drawCircle(const Offset(41, 17), 2.2, pinkLight);

    // Baş
    canvas.drawCircle(const Offset(29, 11), 7, skin);
    // Saç (topuz + perçem)
    canvas.drawArc(const Rect.fromLTWH(21, 2, 16, 14),
        math.pi * 0.9, math.pi * 1.2, true, hair);
    canvas.drawCircle(const Offset(35, 5), 3.4, hair);
    canvas.drawCircle(const Offset(23, 7), 2.2, pinkDark);
    // Yüz
    final eye = Paint()..color = const Color(0xFF333333);
    canvas.drawCircle(const Offset(27, 11), 1.1, eye);
    canvas.drawCircle(const Offset(31.5, 11), 1.1, eye);
    final smile = Paint()
      ..color = const Color(0xFFD6336C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        const Rect.fromLTWH(27, 12.5, 5, 3.5), 0.3, math.pi - 0.6, false, smile);
    // Allık
    canvas.drawCircle(
        const Offset(25, 13.5),
        1.4,
        Paint()..color = const Color(0xFFF8BBD0));
    canvas.drawCircle(
        const Offset(33, 13.5),
        1.4,
        Paint()..color = const Color(0xFFF8BBD0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
