import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_repository.dart';
import '../../widgets_face_avatar.dart';
import '../../config/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _amlBlue = Color(0xFF00AEEF);
const Color _amlBlack = Color(0xFF050505);
const Color _amlSurface = Color(0xFF111111);

class AmlAuthScreen extends StatefulWidget {
  const AmlAuthScreen({super.key});

  @override
  State<AmlAuthScreen> createState() => _AmlAuthScreenState();
}

class _AmlAuthScreenState extends State<AmlAuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();

  final picker = ImagePicker();
  XFile? avatarFile;

  bool register = false;
  bool loading = false;
  String? error;
  String profileType = 'fan';

  final profileTypes = const [
    ('fan', 'Fan', Icons.person_outline),
    ('fighter', 'Combattant', Icons.sports_mma_outlined),
    ('coach', 'Coach', Icons.sports_handball_outlined),
    ('referee', 'Arbitre', Icons.gavel_outlined),
    ('media', 'Média', Icons.camera_alt_outlined),
    ('organization', 'Organisation', Icons.business_outlined),
    ('other', 'Autre', Icons.groups_outlined),
  ];

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    username.dispose();
    phone.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> pickAvatar() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1000);
    if (file != null && mounted) setState(() => avatarFile = file);
  }

  Future<void> submit() async {
    final client = SupabaseService.client;
    if (client == null) {
      setState(() => error = SupabaseService.configurationMessage);
      return;
    }

    if (!register) {
      if (email.text.trim().isEmpty || password.text.length < 6) {
        setState(() => error = 'Entre un e-mail valide et un mot de passe d’au moins 6 caractères.');
        return;
      }
    } else {
      if (firstName.text.trim().isEmpty ||
          lastName.text.trim().isEmpty ||
          username.text.trim().isEmpty ||
          phone.text.trim().isEmpty ||
          city.text.trim().isEmpty ||
          email.text.trim().isEmpty ||
          password.text.length < 6) {
        setState(() => error = 'Remplis au minimum prénom, nom, nom d’utilisateur, téléphone, ville, e-mail et mot de passe.');
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_.-]{3,24}$').hasMatch(username.text.trim())) {
        setState(() => error = 'Le nom d’utilisateur doit contenir 3 à 24 caractères : lettres, chiffres, . _ ou -.');
        return;
      }
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (register) {
        final result = await client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          emailRedirectTo: AppLinks.authRedirectUrl.isEmpty ? null : AppLinks.authRedirectUrl,
          data: {
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
            'username': username.text.trim().toLowerCase(),
            'phone': phone.text.trim(),
            'city': city.text.trim(),
            'profile_type': profileType,
          },
        );

        if (!mounted) return;

        if (result.session == null) {
          // Pas de session (confirmation e-mail) : on garde la photo choisie pour la première connexion.
          if (avatarFile != null) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pending_avatar_path', avatarFile!.path);
              await prefs.setString('pending_avatar_email', email.text.trim().toLowerCase());
            } catch (_) {}
          }
          setState(() => error = 'Compte créé. Confirme ton adresse e-mail, puis connecte-toi : ton profil sera prêt automatiquement.');
          return;
        }

        String? avatarUrl;
        if (avatarFile != null) {
          try {
            final bytes = await avatarFile!.readAsBytes();
            avatarUrl = await ProfileRepository().uploadAvatar(bytes, 'jpg');
          } catch (_) {
            // Le compte est déjà créé : la photo pourra être ajoutée plus tard.
          }
        }

        await ProfileRepository().upsertProfile(
          firstName: firstName.text.trim(),
          lastName: lastName.text.trim(),
          username: username.text.trim().toLowerCase(),
          phone: phone.text.trim(),
          city: city.text.trim(),
          profileType: profileType,
          avatarUrl: avatarUrl,
        );
      } else {
        await client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        // Reprend les informations d'inscription (nom, pseudo, ville…) et la photo en attente.
        final profiles = ProfileRepository();
        await profiles.loadMine();
        await profiles.applyPendingAvatar(email.text);
      }

      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Impossible de finaliser le compte. Vérifie tes informations et réessaie.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _amlBlack,
      appBar: AppBar(
        title: Text(register ? 'Créer mon compte' : 'Compte AML', style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _amlSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _AvatarPicker(file: avatarFile, onTap: register ? pickAvatar : null),
                const SizedBox(height: 12),
                Text(
                  register ? 'Rejoins AML Arena' : 'Connecte-toi à AML Arena',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  register
                      ? 'Une inscription rapide. Tu pourras compléter ton profil plus tard.'
                      : 'Ton e-mail reste privé et sert uniquement à la connexion.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 20),

                if (register) ...[
                  Row(children: [
                    Expanded(child: _field(firstName, 'Prénom', Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(lastName, 'Nom', Icons.badge_outlined)),
                  ]),
                  const SizedBox(height: 12),
                  _field(username, 'Nom d’utilisateur', Icons.alternate_email, helper: '@tonnom'),
                  const SizedBox(height: 12),
                  _field(phone, 'Numéro de téléphone', Icons.phone_outlined, keyboard: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(city, 'Ville', Icons.location_on_outlined),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('TYPE DE PROFIL', style: TextStyle(color: _amlBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profileTypes.map((item) {
                      final selected = profileType == item.$1;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(item.$2),
                        avatar: Icon(item.$3, size: 17),
                        selectedColor: _amlBlue.withOpacity(.25),
                        backgroundColor: Colors.white.withOpacity(.05),
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700, fontSize: 11),
                        onSelected: (_) => setState(() => profileType = item.$1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                _field(email, 'E-mail de connexion', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(password, 'Mot de passe', Icons.lock_outline, obscure: true),

                if (error != null) ...[
                  const SizedBox(height: 14),
                  Text(error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amlBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: loading
                        ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(register ? 'CRÉER MON COMPTE' : 'SE CONNECTER', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                            register = !register;
                            error = null;
                          }),
                  child: Text(register ? 'J’ai déjà un compte' : 'Créer un compte'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: helper,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final XFile? file;
  final VoidCallback? onTap;
  const _AvatarPicker({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
        AmlFaceAvatar(radius: 45, backgroundColor: const Color(0xFF17232A), image: file != null ? FileImageCompat(file!) : null, child: file == null ? const Icon(Icons.person, size: 42, color: Colors.white38) : null),
        if (onTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(color: _amlBlue, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

// A small adapter keeps the auth screen mobile-only without adding
// platform-specific code to the rest of the UI.
ImageProvider<Object>? FileImageCompat(XFile file) => FileImage(File(file.path));
