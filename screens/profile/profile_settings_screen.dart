import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

const _blue = Color(0xFF00AEEF);

class AmlProfileSettingsScreen extends StatefulWidget {
  final bool showFighterCard;
  const AmlProfileSettingsScreen({super.key, this.showFighterCard = false});
  @override State<AmlProfileSettingsScreen> createState() => _AmlProfileSettingsScreenState();
}

class _AmlProfileSettingsScreenState extends State<AmlProfileSettingsScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;
  bool obscure = true;
  @override void dispose() { password.dispose(); confirm.dispose(); super.dispose(); }

  Future<void> _changePassword() async {
    if (password.text.length < 8) { _message('Le mot de passe doit contenir au moins 8 caractères.'); return; }
    if (password.text != confirm.text) { _message('Les deux mots de passe ne correspondent pas.'); return; }
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) { _message('Connecte-toi pour modifier ton mot de passe.'); return; }
    setState(() => saving = true);
    try {
      await client.auth.updateUser(UserAttributes(password: password.text));
      password.clear(); confirm.clear();
      if (mounted) _message('Mot de passe modifié avec succès.');
    } catch (e) { if (mounted) _message('Modification impossible : $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: Text(widget.showFighterCard ? 'Ma carte AML' : 'Paramètres', style: const TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      if (widget.showFighterCard) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(18), border: Border.all(color: _blue.withOpacity(.35))), child: const Column(children: [Icon(Icons.badge_outlined, size: 54, color: _blue), SizedBox(height: 12), Text('Carte membre AML', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 8), Text('Ta carte de membre est associée à ton compte connecté. Le QR de contrôle événementiel est généré séparément pour chaque billet valide.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.4))])),
      const Text('SÉCURITÉ DU COMPTE', style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Nouveau mot de passe', suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscure = !obscure)))),
      const SizedBox(height: 10),
      TextField(controller: confirm, obscureText: obscure, decoration: const InputDecoration(labelText: 'Confirmer le mot de passe')),
      const SizedBox(height: 14),
      SizedBox(height: 50, child: ElevatedButton(onPressed: saving ? null : _changePassword, style: ElevatedButton.styleFrom(backgroundColor: _blue), child: saving ? const CircularProgressIndicator() : const Text('MODIFIER LE MOT DE PASSE', style: TextStyle(fontWeight: FontWeight.w900)))),
      const SizedBox(height: 18),
      const ListTile(leading: Icon(Icons.verified_user_outlined, color: _blue), title: Text('Protection du compte'), subtitle: Text('Les changements sont envoyés à Supabase Auth. Ne partage jamais ton mot de passe.', style: TextStyle(color: Colors.white54))),
    ]),
  );
}
