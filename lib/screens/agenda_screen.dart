import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Aylık ajanda: takvim ızgarası + seçili güne not girişi.
/// Notlu günlerde nokta görünür, bugün halkayla işaretlidir.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime _month;
  late DateTime _selected;
  final _textCtrl = TextEditingController();

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];
  static const _weekdays = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() => setState(() {
        _month = DateTime(_month.year, _month.month - 1);
      });

  void _nextMonth() => setState(() {
        _month = DateTime(_month.year, _month.month + 1);
      });

  void _goToday() => setState(() {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
        _selected = DateTime(now.year, now.month, now.day);
      });

  Future<void> _add() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    await context.read<AppStore>().addAgendaEntry(_selected, text);
    _textCtrl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  String _fmtDay(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final leading =
        DateTime(_month.year, _month.month, 1).weekday - 1;
    final marked =
        store.agendaDaysInMonth(_month.year, _month.month);
    final today = DateTime.now();
    bool isToday(int day) =>
        today.year == _month.year &&
        today.month == _month.month &&
        today.day == day;
    final notes = store.agendaForDay(_selected);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Aylık Ajanda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Önceki ay',
                        onPressed: _prevMonth,
                      ),
                      Expanded(
                        child: Text(
                          '${_months[_month.month - 1]} ${_month.year}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToday,
                        child: const Text('Bugün'),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.chevron_right_rounded),
                        tooltip: 'Sonraki ay',
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final w in _weekdays)
                        Expanded(
                          child: Center(
                            child: Text(w,
                                style:
                                    GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                )),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: leading + daysInMonth,
                    itemBuilder: (ctx, i) {
                      if (i < leading) {
                        return const SizedBox.shrink();
                      }
                      final day = i - leading + 1;
                      final selected = _selected.year ==
                              _month.year &&
                          _selected.month == _month.month &&
                          _selected.day == day;
                      final hasNotes = marked.contains(day);
                      return InkWell(
                        onTap: () => setState(() {
                          _selected = DateTime(
                              _month.year, _month.month, day);
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : isToday(day)
                                      ? AppColors.primary
                                      : Colors.transparent,
                              width: selected ? 0 : 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style:
                                    GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: selected ||
                                          isToday(day)
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasNotes
                                      ? (selected
                                          ? Colors.white
                                          : AppColors.primary)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_fmtDay(_selected)} — Notlar (${notes.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Not yazın… (Enter = kaydet)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 1,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _add,
                        tooltip: 'Not ekle',
                        icon: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (notes.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text(
                              'Bu güne yazılmış not yok.',
                              style: TextStyle(
                                  color: Colors.grey))),
                    )
                  else
                    for (final n in notes)
                      Container(
                        margin:
                            const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                                Icons.event_note_rounded,
                                size: 18,
                                color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(n.text)),
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20),
                              tooltip: 'Notu sil',
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(),
                              onPressed: () => context
                                  .read<AppStore>()
                                  .deleteAgendaEntry(n.id),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          if (store.agendaEntries.isEmpty)
            const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Ajanda boş',
              subtitle:
                  'Gün seçip not yazın; dolu günlerde takvimde nokta görünür.',
            ),
        ],
      ),
    );
  }
}
