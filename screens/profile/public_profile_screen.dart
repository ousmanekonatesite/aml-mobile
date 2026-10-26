import 'package:flutter/material.dart';
import '../../services/public_profile_repository.dart';
import '../../services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../messages/messages_screen.dart';
import '../../widgets_face_avatar.dart';
import '../../services/follow_service.dart';

const Color _ppBlue = Color(0xFF00AEEF);
const Color _ppBlack = Color(0xFF050505);
const Color _ppSurface = Color(0xFF111111);

class AmlPublicProfileScreen extends StatefulWidget {
  final String userId;
  const AmlPublicProfileScreen({super.key, required this.userId});

  @override
  State<AmlPublicProfileScreen> createState() => _AmlPublicProfileScreenState();
}

class _AmlPublicProfileScreenState extends State<AmlPublicProfileScreen> {
  final repo = PublicProfileRepository();
  Map<String, dynamic>? profile;
  Map<String, int> counts = {'followers': 0, 'following': 0, 'posts': 0};
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool following = false;
  String followStatus = 'none';
  String? followRequestId;
  bool busy = false;

  bool get isMe => SupabaseService.client?.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await Future.wait([
      repo.load(widget.userId),
      repo.counts(widget.userId),
      repo.posts(widget.userId),
      FollowService.status(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      profile = result[0] as Map<String, dynamic>?;
      counts = result[1] as Map<String, int>;
      posts = result[2] as List<Map<String, dynamic>>;
      final st = result[3] as Map<String, dynamic>;
      followStatus = st['status']?.toString() ?? 'none';
      followRequestId = st['request_id']?.toString();
      following = followStatus == 'connected';
      loading = false;
    });
  }

  Future<void> _followAction(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      var message = '';
      switch (action) {
        case 'request':
          final s = await FollowService.request(widget.userId);
          message = s == 'connected' ? 'Vous vous suivez maintenant.' : 'Demande envoyée. Tu seras abonné dès qu’elle sera acceptée.';
          break;
        case 'cancel':
          await FollowService.cancel(widget.userId);
          message = 'Demande annulée.';
          break;
        case 'accept':
          if (followRequestId != null) await FollowService.respond(followRequestId!, true);
          message = 'Demande acceptée. Vous pouvez maintenant vous écrire.';
          break;
        case 'decline':
          if (followRequestId != null) await FollowService.respond(followRequestId!, false);
          message = 'Demande refusée.';
          break;
        case 'remove':
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Ne plus se suivre ?'),
              content: const Text('Vous ne pourrez plus vous écrire ni recevoir vos publications, sauf nouvelle demande acceptée.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer'))],
            ),
          );
          if (ok != true) break;
          await FollowService.remove(widget.userId);
          message = 'Vous ne vous suivez plus.';
          break;
      }
      await _load();
      if (mounted && message.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> _followActions() {
    final connected = followStatus == 'connected';
    final message = SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: connected && profile != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmlMessageThreadScreen(otherUserId: widget.userId, profile: profile!))) : null,
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: Text(connected ? 'ENVOYER UN MESSAGE' : 'MESSAGE (APRÈS ACCEPTATION)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        style: OutlinedButton.styleFrom(foregroundColor: _ppBlue, side: BorderSide(color: _ppBlue.withValues(alpha: .55))),
      ),
    );
    final Widget main;
    switch (followStatus) {
      case 'connected':
        main = ElevatedButton.icon(
          onPressed: busy ? null : () => _followAction('remove'),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('SUIVI MUTUEL', style: TextStyle(fontWeight: FontWeight.w900)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF17232A), foregroundColor: Colors.white),
        );
        break;
      case 'pending_out':
        main = ElevatedButton.icon(
          onPressed: busy ? null : () => _followAction('cancel'),
          icon: const Icon(Icons.hourglass_top, size: 18),
          label: const Text('DEMANDE ENVOYÉE · ANNULER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF17232A), foregroundColor: Colors.white),
        );
        break;
      case 'pending_in':
        main = Row(children: [
          Expanded(child: ElevatedButton(onPressed: busy ? null : () => _followAction('accept'), style: ElevatedButton.styleFrom(backgroundColor: _ppBlue, foregroundColor: Colors.white), child: const Text('ACCEPTER', style: TextStyle(fontWeight: FontWeight.w900)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: busy ? null : () => _followAction('decline'), child: const Text('REFUSER'))),
        ]);
        break;
      default:
        main = ElevatedButton.icon(
          onPressed: busy ? null : () => _followAction('request'),
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('SUIVRE', style: TextStyle(fontWeight: FontWeight.w900)),
          style: ElevatedButton.styleFrom(backgroundColor: _ppBlue, foregroundColor: Colors.white),
        );
    }
    return [SizedBox(width: double.infinity, height: 44, child: main), const SizedBox(height: 8), message];
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: _ppBlack,
        body: Center(child: CircularProgressIndicator(color: _ppBlue)),
      );
    }

    if (profile == null) {
      return Scaffold(
        backgroundColor: _ppBlack,
        appBar: AppBar(title: const Text('Profil AML')),
        body: const Center(child: Text('Profil introuvable.', style: TextStyle(color: Colors.white54))),
      );
    }

    final username = profile!['username']?.toString();
    final first = profile!['first_name']?.toString() ?? '';
    final last = profile!['last_name']?.toString() ?? '';
    final name = ('$first $last').trim().isEmpty ? 'Membre AML' : ('$first $last').trim();
    final type = _type(profile!['profile_type']?.toString());
    final city = profile!['city']?.toString();
    final avatar = profile!['avatar_url']?.toString();
    final verified = profile!['is_verified'] == true;

    return Scaffold(
      backgroundColor: _ppBlack,
      appBar: AppBar(title: const Text('Profil AML', style: TextStyle(fontWeight: FontWeight.w900))),
      body: RefreshIndicator(
        color: _ppBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF003B55), Color(0xFF001B27)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _ppBlue.withValues(alpha: .24)),
              ),
              child: Column(
                children: [
                  AmlFaceAvatar(radius: 44, backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, size: 42, color: Colors.white38) : null),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: _ppBlue, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(username != null && username.isNotEmpty ? '@$username' : 'Nom d’utilisateur à définir', style: const TextStyle(color: _ppBlue, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text('$type${city == null || city.isEmpty ? '' : ' • $city'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 15),
                  if (!isMe) ..._followActions(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(value: counts['posts'] ?? 0, label: 'Publications'),
                _Stat(value: counts['followers'] ?? 0, label: 'Abonnés'),
                _Stat(value: counts['following'] ?? 0, label: 'Abonnements'),
              ],
            ),
            const SizedBox(height: 22),
            const Text('PUBLICATIONS', style: TextStyle(color: _ppBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 9),
            if (posts.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Aucune publication.', style: TextStyle(color: Colors.white54))))
            else
              ...posts.map((post) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: _ppSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
                    child: Text(post['content']?.toString() ?? '', style: TextStyle(color: Colors.white.withValues(alpha: .88), height: 1.4)),
                  )),
          ],
        ),
      ),
    );
  }

  String _type(String? value) => {
        'fan': 'Fan',
        'fighter': 'Combattant',
        'coach': 'Coach',
        'referee': 'Arbitre',
        'media': 'Média',
        'organization': 'Organisation',
        'other': 'Autre',
      }[value] ?? 'Membre AML';
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: _ppSurface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
          child: Column(children: [
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ]),
        ),
      );
}
