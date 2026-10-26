import 'package:flutter/material.dart';
import '../../services/prediction_repository.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_screen.dart';
import 'prediction_stats_panel.dart';
import '../../widgets_face_avatar.dart';

const _blue = Color(0xFF00AEEF);
const _surface = Color(0xFF111111);

class AmlPredictionsScreen extends StatefulWidget {
  final String? fightId;
  final bool embedded;
  const AmlPredictionsScreen({super.key, this.fightId, this.embedded = false});

  @override
  State<AmlPredictionsScreen> createState() => _AmlPredictionsScreenState();
}

class _AmlPredictionsScreenState extends State<AmlPredictionsScreen> {
  final repo = PredictionRepository();
  bool loading = true;
  int xp = 0;
  List<Map<String, dynamic>> items = [];
  String filter = 'Toutes';

  final Map<String, String?> winnerPicks = {};
  final Map<String, String?> methodPicks = {};
  final Map<String, String?> roundPicks = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await repo.upcoming(fightId: widget.fightId);
      final points = await repo.myXp();
      if (!mounted) return;

      for (final item in data) {
        final mine = item['my_prediction'];
        if (mine is Map) {
          final id = item['id'].toString();
          winnerPicks[id] = mine['winner_option_id']?.toString();
          methodPicks[id] = mine['method_option_id']?.toString();
          roundPicks[id] = mine['round_option_id']?.toString();
        }
      }

      setState(() {
        items = data;
        xp = points;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les pronostics : $e')),
      );
    }
  }

  Future<void> _submit(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final winner = winnerPicks[id];
    final method = methodPicks[id];
    final round = roundPicks[id];

    if (winner == null && method == null && round == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis au moins une option : vainqueur, méthode ou round.'),
        ),
      );
      return;
    }

    if (item['my_prediction'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu as déjà pronostiqué ce combat.')),
      );
      return;
    }

    if (SupabaseService.client?.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AmlAuthScreen()),
      );
      if (mounted) await _load();
      return;
    }

    try {
      await repo.submit(
        predictionId: id,
        winnerOptionId: winner,
        methodOptionId: method,
        roundOptionId: round,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pronostic enregistré. Bonne chance !')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<Map<String, dynamic>> get visible {
    if (filter == 'Toutes') return items;
    return items.where((item) {
      final c = item['competition'];
      return c is Map && c['name']?.toString() == filter;
    }).toList();
  }

  List<String> get _competitionNames {
    final names = <String>{};
    for (final item in items) {
      final c = item['competition'];
      if (c is Map && (c['name']?.toString().trim().isNotEmpty ?? false)) {
        names.add(c['name'].toString());
      }
    }
    final result = names.toList()..sort();
    return result;
  }

  List<Map<String, dynamic>> _options(
    Map<String, dynamic> item,
    String type,
  ) {
    final options = List<Map<String, dynamic>>.from(
      item['prediction_options'] ?? const [],
    );
    return options.where((o) => o['option_type'] == type).toList();
  }

  bool _locked(Map<String, dynamic> item) {
    final value = item['lock_at'];
    if (value == null) return false;
    final date = DateTime.tryParse(value.toString());
    if (date == null) return false;
    return DateTime.now().toUtc().isAfter(date.toUtc());
  }

  Widget _embeddedBody() {
    if (loading) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: _blue)));
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Le pronostic de ce combat sera disponible très bientôt.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
      );
    }
    return Column(children: items.map(_card).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _embeddedBody();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Pronos MMA',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '$xp XP',
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              color: _blue,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  _Hero(xp: xp),
                  const SizedBox(height: 18),
                  const Text(
                    'COMPÉTITIONS',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _Filter(
                          label: 'Toutes',
                          selected: filter == 'Toutes',
                          onTap: () => setState(() => filter = 'Toutes'),
                        ),
                        ..._competitionNames.map(
                          (name) => _Filter(
                            label: name,
                            selected: filter == name,
                            onTap: () => setState(() => filter = name),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PRONOSTICS DISPONIBLES',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        widget.fightId == null
                            ? 'Aucun pronostic officiel n’est actuellement disponible.'
                            : 'Aucun pronostic ouvert pour ce combat. L’administration doit publier le pronostic avant de pouvoir participer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ...visible.map(_card),
                  const SizedBox(height: 20),
                  const _XpRules(),
                ],
              ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final fight = item['fight'] as Map<String, dynamic>?;
    final fighterA = fight?['fighter_a'] as Map<String, dynamic>?;
    final fighterB = fight?['fighter_b'] as Map<String, dynamic>?;
    final event = item['event'];
    final competition = item['competition'];
    final submitted = item['my_prediction'] != null;
    final locked = _locked(item);

    final winnerOptions = _options(item, 'winner');
    final methodOptions = _options(item, 'method');
    final roundOptions = _options(item, 'round');

    final eventName = event is Map ? event['name']?.toString() : null;
    final competitionName = competition is Map
        ? competition['name']?.toString()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: submitted ? _blue.withOpacity(.55) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (competitionName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    competitionName,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (eventName != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eventName,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _fightersRow(fighterA, fighterB),
          const SizedBox(height: 12),
          PredictionStatsPanel(predictionId: id),
          const SizedBox(height: 14),
          if (!submitted && !locked)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Pronostique sur une ou plusieurs options : vainqueur, méthode, round. Appuie à nouveau sur un choix pour le retirer.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ),
          _choiceSection(
            title: 'Vainqueur',
            options: winnerOptions,
            selected: winnerPicks[id],
            disabled: submitted || locked,
            onChanged: (value) => setState(() => winnerPicks[id] = winnerPicks[id] == value ? null : value),
          ),
          const SizedBox(height: 12),
          _choiceSection(
            title: 'Méthode',
            options: methodOptions,
            selected: methodPicks[id],
            disabled: submitted || locked,
            onChanged: (value) => setState(() => methodPicks[id] = methodPicks[id] == value ? null : value),
          ),
          const SizedBox(height: 12),
          _choiceSection(
            title: 'Round',
            options: roundOptions,
            selected: roundPicks[id],
            disabled: submitted || locked,
            onChanged: (value) => setState(() => roundPicks[id] = roundPicks[id] == value ? null : value),
          ),
          const SizedBox(height: 14),
          if (submitted)
            _statusBox(
              Icons.check_circle_outline,
              'Pronostic enregistré',
              'Ton choix est maintenant verrouillé.',
            )
          else if (locked)
            _statusBox(
              Icons.lock_outline,
              'Pronostics fermés',
              'La période de pronostic est terminée.',
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'VALIDER MON PRONOSTIC',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _XpItem('+${item['xp_participation'] ?? 0}', 'Participation'),
              _XpItem('+${item['xp_winner'] ?? 0}', 'Vainqueur'),
              _XpItem('+${item['xp_method'] ?? 0}', 'Méthode'),
              _XpItem('+${item['xp_round'] ?? 0}', 'Round'),
              _XpItem('+${item['xp_exact'] ?? 0}', 'Exact'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fightersRow(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    return Row(
      children: [
        Expanded(child: _fighter(a, Alignment.centerLeft)),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'VS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(child: _fighter(b, Alignment.centerRight)),
      ],
    );
  }

  Widget _fighter(Map<String, dynamic>? fighter, Alignment alignment) {
    final first = fighter?['first_name']?.toString() ?? '';
    final last = fighter?['last_name']?.toString() ?? '';
    final name = '$first $last'.trim();
    final photo = fighter?['photo_url']?.toString();
    final isLeft = alignment == Alignment.centerLeft;

    return Column(
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        AmlFaceAvatar(radius: 29, backgroundColor: const Color(0xFF202020), image: photo != null && photo.isNotEmpty
              ? NetworkImage(photo)
              : null, child: photo == null || photo.isEmpty
              ? const Icon(Icons.person_outline, color: Colors.white38)
              : null),
        const SizedBox(height: 7),
        Text(
          name.isEmpty ? 'Combattant à confirmer' : name,
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (fighter?['weight_category'] != null)
          Text(
            fighter!['weight_category'].toString(),
            textAlign: isLeft ? TextAlign.left : TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
            ),
          ),
      ],
    );
  }

  Widget _choiceSection({
    required String title,
    required List<Map<String, dynamic>> options,
    required String? selected,
    required bool disabled,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...options.map((option) {
          final id = option['id'].toString();
          final selectedNow = selected == id;
          return GestureDetector(
            onTap: disabled ? null : () => onChanged(id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selectedNow
                    ? _blue.withOpacity(.15)
                    : Colors.white.withOpacity(.025),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selectedNow ? _blue : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedNow
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selectedNow ? _blue : Colors.white38,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      option['label']?.toString() ?? '',
                      style: TextStyle(
                        color: disabled ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statusBox(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : _surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _blue : Colors.white10,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  final int xp;
  const _Hero({required this.xp});

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_blue, Color(0xFF003B55), Color(0xFF001B27)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, size: 42, color: Colors.white),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JOUE. PRONOSTIQUE. GAGNE.',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Ton score : $xp XP. Pronostique les combats réels.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _XpItem extends StatelessWidget {
  final String value;
  final String label;
  const _XpItem(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
        ],
      );
}

class _XpRules extends StatelessWidget {
  const _XpRules();

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMMENT GAGNER DES XP',
              style: TextStyle(
                color: _blue,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 10),
            Text('• Participation : +5 XP'),
            Text('• Bon vainqueur : +20 XP'),
            Text('• Bonne méthode : +10 XP'),
            Text('• Bon round : +10 XP'),
            Text('• Pronostic exact : +25 XP'),
          ],
        ),
      );
}
