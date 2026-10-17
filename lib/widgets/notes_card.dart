import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../state/app_store.dart';
import '../theme/app_colors.dart';

/// Paneldeki notlar kartı: yazılı not ekleme + sesli not kaydetme/dinleme.
/// Ses dosyaları yalnızca bu cihazda saklanır, yazılar eşitlenir.
class NotesCard extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const NotesCard({super.key, this.onSeeAll});

  @override
  State<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<NotesCard> {
  final _textCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _playingId;
  bool _busy = false;

  static const int _maxSeconds = 120;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _addText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    await context.read<AppStore>().addNote(text);
    _textCtrl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopAndSave();
      return;
    }
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Mikrofon izni verilmedi.')),
          );
        }
        return;
      }
      await _stopPlayback();
      String path;
      if (kIsWeb) {
        path =
            'note_${DateTime.now().millisecondsSinceEpoch}.wav';
      } else {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      if (mounted) {
        setState(() {
          _recording = true;
          _seconds = 0;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
          if (!mounted) return;
          if (_seconds + 1 >= _maxSeconds) {
            await _stopAndSave();
          } else {
            setState(() => _seconds++);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Ses kaydı bu cihazda desteklenmiyor ($e)')),
        );
      }
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt durdurulamadı: $e')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null || path.isEmpty) return;

    setState(() => _busy = true);
    try {
      final bytes = await _readAudioBytes(path);
      final store = context.read<AppStore>();
      final label = _textCtrl.text.trim().isEmpty
          ? 'Sesli not'
          : _textCtrl.text.trim();
      final note = await store.addNote(label);
      if (bytes != null && bytes.isNotEmpty) {
        await store.setNoteAudio(note.id, base64Encode(bytes));
      } else {
        // Bayt okunamadıysa web oturum URL'si ile çalınabilir.
        _sessionUrls[note.id] = path;
        await store.setNoteAudio(note.id, '');
      }
      _textCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sesli not kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Oturum içi web blob URL'leri (bayt okunamazsa yedek çalma yolu).
  final Map<String, String> _sessionUrls = {};

  Future<Uint8List?> _readAudioBytes(String path) async {
    try {
      if (kIsWeb) {
        if (path.startsWith('blob:')) {
          final res = await http.get(Uri.parse(path));
          if (res.statusCode == 200) return res.bodyBytes;
          return null;
        }
        return null;
      }
      final file = File(path);
      if (await file.exists()) return await file.readAsBytes();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) setState(() => _playingId = null);
  }

  Future<void> _togglePlay(String noteId) async {
    if (_playingId == noteId) {
      await _stopPlayback();
      return;
    }
    await _stopPlayback();
    final store = context.read<AppStore>();
    try {
      final b64 = store.noteAudioBase64(noteId);
      if (b64 != null && b64.isNotEmpty) {
        await _player.play(BytesSource(base64Decode(b64)));
      } else if (_sessionUrls[noteId] != null) {
        await _player.play(UrlSource(_sessionUrls[noteId]!));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Ses dosyası bu cihazda bulunamadı.')),
          );
        }
        return;
      }
      if (mounted) setState(() => _playingId = noteId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses çalınamadı: $e')),
        );
      }
    }
  }

  String _fmtTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDur(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  /// Hatırlatıcı rozeti: yoksa saat ikonu, varsa tarih-saat + iptal.
  Widget _reminderChip(BuildContext context, dynamic n) {
    final DateTime? at = n.reminderAt as DateTime?;
    if (at == null) {
      return InkWell(
        onTap: () => _pickReminder(context, n.id as String),
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_add,
                  size: 14, color: AppColors.primary),
              SizedBox(width: 2),
              Text('Hatırlat',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    final past = at.isBefore(DateTime.now());
    return InkWell(
      onTap: () => _pickReminder(context, n.id as String,
          initial: at),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: past
              ? Colors.grey.shade200
              : AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_on,
                size: 14,
                color: past
                    ? Colors.grey
                    : AppColors.primary),
            const SizedBox(width: 2),
            Text(_fmtTime(at),
                style: TextStyle(
                    fontSize: 11,
                    color: past
                        ? Colors.grey
                        : AppColors.primary,
                    fontWeight: FontWeight.w600)),
            InkWell(
              onTap: () => context
                  .read<AppStore>()
                  .setNoteReminder(n.id as String, null),
              child: const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(Icons.close,
                    size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminder(BuildContext context, String noteId,
      {DateTime? initial}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    if (at.isBefore(now)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Geçmiş bir saate hatırlatıcı kurulamaz.')),
        );
      }
      return;
    }
    await context.read<AppStore>().setNoteReminder(noteId, at);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Hatırlatıcı kuruldu: ${_fmtTime(at)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final notes = store.notes;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notlar (${notes.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (widget.onSeeAll != null)
                InkWell(
                  onTap: widget.onSeeAll,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Tümü',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Yazılı veya sesli — yazılar tüm cihazlarda görünür.',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Not yazın… (Enter = kaydet)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addText(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton.filled(
                    onPressed: _busy ? null : _addText,
                    tooltip: 'Yazılı not ekle',
                    icon: const Icon(Icons.add, size: 20),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: _busy ? null : _toggleRecord,
                    tooltip: _recording
                        ? 'Kaydı durdur ve kaydet'
                        : 'Sesli not kaydet',
                    style: IconButton.styleFrom(
                      backgroundColor: _recording
                          ? Colors.red.shade50
                          : AppColors.primaryMuted,
                    ),
                    icon: Icon(
                      _recording ? Icons.stop : Icons.mic,
                      color: _recording
                          ? Colors.red
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('Kaydediliyor ${_fmtDur(_seconds)} / 02:00',
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'Durdurmak için mikrofona tekrar basın.',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ),
                ],
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: Text('Henüz not yok.',
                      style:
                          TextStyle(color: Colors.grey))),
            )
          else
            for (final n in notes.take(6))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.hasAudio)
                      IconButton(
                        icon: Icon(
                          _playingId == n.id
                              ? Icons.stop_circle
                              : Icons.play_circle_fill,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        tooltip: 'Sesi dinle',
                        onPressed: () => _togglePlay(n.id),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(n.text.isEmpty
                              ? '(boş not)'
                              : n.text),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_fmtTime(n.createdAt)}${n.hasAudio ? ' • sesli' : ''}',
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11),
                              ),
                              _reminderChip(context, n),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20),
                      tooltip: 'Notu sil',
                      onPressed: () => context
                          .read<AppStore>()
                          .deleteNote(n.id),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
