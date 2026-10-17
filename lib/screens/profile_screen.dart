import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import '../theme/app_colors.dart';

/// Profil: fotoğraf + isim + ünvan. Paneldeki karşılama bu ismi kullanır.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _nameCtrl = TextEditingController(text: store.profileName);
    _titleCtrl = TextEditingController(text: store.profileTitle);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      await context
          .read<AppStore>()
          .setProfilePhoto(base64Encode(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  ImageProvider? _photoOf(AppStore store) {
    if (store.profilePhotoBase64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(store.profilePhotoBase64));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final name = _nameCtrl.text;
    final title = _titleCtrl.text;
    await context.read<AppStore>().updateProfile(
          name: name,
          title: title,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil kaydedildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final photo = _photoOf(store);
    final first = store.greetingName;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.primaryMuted,
                          backgroundImage: photo,
                          child: photo == null
                              ? const Icon(Icons.person,
                                  size: 52,
                                  color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library,
                        size: 16),
                    label: const Text('Fotoğraf seç'),
                  ),
                  if (photo != null)
                    TextButton.icon(
                      onPressed: () => context
                          .read<AppStore>()
                          .clearProfilePhoto(),
                      icon: const Icon(Icons.delete_outline,
                          size: 16),
                      label: const Text('Fotoğrafı kaldır'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'İsim (örn. Melike Yılmaz)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Ünvan (örn. Diyetisyen)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : () => _saveProfile(),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Önizleme',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(
                    first.isEmpty
                        ? 'Hoş Geldiniz 👋'
                        : 'Hoşgeldiniz, $first',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.text),
                  ),
                  if (store.profileTitle.trim().isNotEmpty)
                    Text(store.profileTitle.trim(),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
