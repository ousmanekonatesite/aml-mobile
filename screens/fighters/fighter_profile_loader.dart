import 'package:flutter/material.dart';
import '../../services/fighter_repository.dart';
import 'fighter_profile_screen.dart';

/// Ouvre le profil complet d'un combattant AML à partir de son identifiant
/// (depuis une carte de combat, la page d'un combat ou l'accueil).
class FighterProfileLoader extends StatefulWidget {
  final String fighterId;
  const FighterProfileLoader({super.key, required this.fighterId});

  /// Ouvre le profil si l'identifiant correspond à un combattant AML (sinon ne fait rien).
  static void open(BuildContext context, String? fighterId) {
    if (fighterId == null || fighterId.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => FighterProfileLoader(fighterId: fighterId)));
  }

  @override
  State<FighterProfileLoader> createState() => _FighterProfileLoaderState();
}

class _FighterProfileLoaderState extends State<FighterProfileLoader> {
  Map<String, dynamic>? fighter;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await FighterRepository().getFighters();
      final found = all.where((f) => f['id']?.toString() == widget.fighterId).toList();
      if (mounted) setState(() { fighter = found.isEmpty ? null : found.first; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = fighter;
    if (f != null) return FighterProfileScreen(fighter: f);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: loading
            ? const CircularProgressIndicator(color: Color(0xFF00AEEF))
            : const Padding(padding: EdgeInsets.all(32), child: Text('Ce profil n’est pas disponible pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60))),
      ),
    );
  }
}
