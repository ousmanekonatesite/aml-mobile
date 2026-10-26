import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile_repository.dart';
import '../../services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets_face_avatar.dart';

const Color _eBlue = Color(0xFF00AEEF);
const Color _eBlack = Color(0xFF050505);
const Color _eSurface = Color(0xFF111111);

class AmlEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  const AmlEditProfileScreen({super.key, this.initialProfile});
  @override State<AmlEditProfileScreen> createState() => _AmlEditProfileScreenState();
}

class _AmlEditProfileScreenState extends State<AmlEditProfileScreen> {
  final repo = ProfileRepository();
  final picker = ImagePicker();
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController username;
  late final TextEditingController phone;
  late final TextEditingController city;
  XFile? avatarFile;
  String? avatarUrl;
  String profileType = 'fan';
  bool saving = false;
  String? error;

  static const profileTypes = [
    ('fan', 'Fan', Icons.person_outline),
    ('fighter', 'Combattant', Icons.sports_mma_outlined),
    ('coach', 'Coach', Icons.sports_handball_outlined),
    ('referee', 'Arbitre', Icons.gavel_outlined),
    ('media', 'Média', Icons.camera_alt_outlined),
    ('organization', 'Organisation', Icons.business_outlined),
    ('other', 'Autre', Icons.groups_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ?? {};
    firstName = TextEditingController(text: p['first_name']?.toString() ?? '');
    lastName = TextEditingController(text: p['last_name']?.toString() ?? '');
    username = TextEditingController(text: p['username']?.toString() ?? '');
    phone = TextEditingController(text: p['phone']?.toString() ?? '');
    city = TextEditingController(text: p['city']?.toString() ?? '');
    avatarUrl = p['avatar_url']?.toString();
    profileType = p['profile_type']?.toString() ?? 'fan';
  }

  @override
  void dispose() {
    firstName.dispose(); lastName.dispose(); username.dispose(); phone.dispose(); city.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (f != null && mounted) setState(() => avatarFile = f);
  }

  Future<void> _save() async {
    final u = username.text.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty || u.isEmpty || phone.text.trim().isEmpty || city.text.trim().isEmpty) {
      setState(() => error = 'Prénom, nom, nom d’utilisateur, téléphone et ville sont obligatoires.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,24}$').hasMatch(u)) {
      setState(() => error = 'Le nom d’utilisateur doit contenir 3 à 24 caractères : lettres, chiffres, . _ ou -.');
      return;
    }
    final c = SupabaseService.client;
    if (c?.auth.currentUser == null) return;
    setState(() { saving = true; error = null; });
    try {
      var nextAvatar = avatarUrl;
      if (avatarFile != null) {
        nextAvatar = await repo.uploadAvatar(await avatarFile!.readAsBytes(), 'jpg');
      }
      await repo.upsertProfile(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        username: u,
        phone: phone.text.trim(),
        city: city.text.trim(),
        profileType: profileType,
        avatarUrl: nextAvatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.client?.auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: _eBlack,
      appBar: AppBar(title: const Text('Modifier mon profil', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Center(child: GestureDetector(onTap: _pickAvatar, child: Stack(children: [
            AmlFaceAvatar(radius: 52, backgroundColor: const Color(0xFF17232A), image: avatarFile != null ? FileImage(File(avatarFile!.path)) : (avatarUrl != null && avatarUrl!.isNotEmpty ? CachedNetworkImageProvider(avatarUrl!) : null), child: avatarFile == null && (avatarUrl == null || avatarUrl!.isEmpty) ? const Icon(Icons.person, size: 48, color: Colors.white38) : null),
            Positioned(right: 0, bottom: 0, child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: _eBlue, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white))),
          ]))),
          const SizedBox(height: 8),
          const Center(child: Text('Modifier la photo de profil', style: TextStyle(color: _eBlue, fontWeight: FontWeight.w800, fontSize: 11))),
          const SizedBox(height: 20),
          _field(firstName, 'Prénom', Icons.person_outline), const SizedBox(height: 11),
          _field(lastName, 'Nom', Icons.badge_outlined), const SizedBox(height: 11),
          _field(username, 'Nom d’utilisateur', Icons.alternate_email, helper: '@tonnom'), const SizedBox(height: 11),
          _field(phone, 'Numéro de téléphone', Icons.phone_outlined, keyboard: TextInputType.phone), const SizedBox(height: 11),
          _field(city, 'Ville', Icons.location_on_outlined), const SizedBox(height: 16),
          const Text('TYPE DE PROFIL', style: TextStyle(color: _eBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: profileTypes.map((item) { final selected = profileType == item.$1; return ChoiceChip(selected: selected, label: Text(item.$2), avatar: Icon(item.$3, size: 17), selectedColor: _eBlue.withOpacity(.25), backgroundColor: Colors.white.withOpacity(.05), labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700, fontSize: 11), onSelected: (_) => setState(() => profileType = item.$1)); }).toList()),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _eSurface, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.email_outlined, color: Colors.white38), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('E-mail de connexion', style: TextStyle(color: Colors.white54, fontSize: 10)), Text(email, style: const TextStyle(fontWeight: FontWeight.w700))]))])),
          if (error != null) ...[const SizedBox(height: 13), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))],
          const SizedBox(height: 20),
          SizedBox(height: 52, child: ElevatedButton(onPressed: saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: _eBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: saving ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('ENREGISTRER MON PROFIL', style: TextStyle(fontWeight: FontWeight.w900)))),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard, String? helper}) => TextField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: helper, prefixIcon: Icon(icon)));
}
