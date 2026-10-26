import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/follow_service.dart';
import '../../utils/aml_time.dart';
import '../../widgets_face_avatar.dart';
import 'public_profile_screen.dart';

const Color _frBlue = Color(0xFF00AEEF);
const Color _frBlack = Color(0xFF050505);
const Color _frSurface = Color(0xFF111111);

/// Demandes de suivi reçues : accepter = vous vous suivez mutuellement et pouvez vous écrire.
class AmlFollowRequestsScreen extends StatefulWidget {
  const AmlFollowRequestsScreen({super.key});
  @override
  State<AmlFollowRequestsScreen> createState() => _AmlFollowRequestsScreenState();
}

class _AmlFollowRequestsScreenState extends State<AmlFollowRequestsScreen> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await FollowService.incoming();
    if (mounted) setState(() { rows = data; loading = false; });
  }

  Future<void> _respond(Map<String, dynamic> r, bool accept) async {
    final id = r['id'].toString();
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      await FollowService.respond(id, accept);
      if (!mounted) return;
      setState(() => rows.removeWhere((x) => x['id'].toString() == id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? 'Demande acceptée. Vous pouvez maintenant vous écrire.' : 'Demande refusée.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _frBlack,
    appBar: AppBar(title: const Text('Demandes de suivi', style: TextStyle(fontWeight: FontWeight.w900))),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: _frBlue))
        : RefreshIndicator(
            color: _frBlue,
            onRefresh: _load,
            child: rows.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 90),
                    Center(child: Icon(Icons.person_add_alt_1_outlined, size: 48, color: Colors.white24)),
                    SizedBox(height: 14),
                    Center(child: Text('Aucune demande en attente.', style: TextStyle(color: Colors.white54))),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _tile(rows[i]),
                  ),
          ),
  );

  Widget _tile(Map<String, dynamic> r) {
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    final display = name.isNotEmpty ? name : (r['display_name'] ?? r['username'] ?? 'Membre AML').toString();
    final avatar = r['avatar_url']?.toString();
    final id = r['id'].toString();
    final working = busy.contains(id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _frSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmlPublicProfileScreen(userId: r['requester_id'].toString()))),
          child: Row(children: [
            AmlFaceAvatar(radius: 24, backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: const Icon(Icons.person, color: Colors.white54)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(display, style: const TextStyle(fontWeight: FontWeight.w900)),
              if ((r['username'] ?? '').toString().isNotEmpty) Text('@${r['username']}', style: const TextStyle(color: _frBlue, fontSize: 11)),
              Text(amlFormatDateTime(r['created_at']), style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: working ? null : () => _respond(r, true), style: ElevatedButton.styleFrom(backgroundColor: _frBlue, foregroundColor: Colors.white), child: const Text('ACCEPTER', style: TextStyle(fontWeight: FontWeight.w900)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: working ? null : () => _respond(r, false), child: const Text('REFUSER'))),
        ]),
      ]),
    );
  }
}
