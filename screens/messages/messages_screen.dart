import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/messaging_repository.dart';
import '../../utils/aml_time.dart';
import '../../widgets_face_avatar.dart';

const Color _mBlue = Color(0xFF00AEEF);
const Color _mBlack = Color(0xFF050505);
const Color _mSurface = Color(0xFF111111);

class AmlMessagesScreen extends StatefulWidget {
  const AmlMessagesScreen({super.key});
  @override State<AmlMessagesScreen> createState() => _AmlMessagesScreenState();
}

String _amlMessageTime(dynamic value) => amlFormatDateTime(value);

class _AmlMessagesScreenState extends State<AmlMessagesScreen> {
  final repo = MessagingRepository();
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await repo.inbox();
      if (mounted) setState(() { rows = data; loading = false; });
    } catch (e) {
      if (mounted) setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _open(Map<String, dynamic> item) async {
    final profile = Map<String, dynamic>.from(item['profile'] ?? {});
    final id = item['user_id']?.toString();
    if (id == null || id.isEmpty) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AmlMessageThreadScreen(otherUserId: id, profile: profile)));
    if (mounted) _load();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _mBlack,
    appBar: AppBar(
      title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: _mBlue,
      foregroundColor: Colors.white,
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlNewMessageScreen()));
        if (mounted) _load();
      },
      child: const Icon(Icons.edit_outlined),
    ),
    body: RefreshIndicator(
      color: _mBlue,
      onRefresh: _load,
      child: loading
        ? const Center(child: CircularProgressIndicator(color: _mBlue))
        : rows.isEmpty
          ? ListView(children: const [SizedBox(height: 180), Center(child: Text('Aucune conversation.', style: TextStyle(color: Colors.white54)))])
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final x = rows[i];
                final p = Map<String, dynamic>.from(x['profile'] ?? {});
                final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                final avatar = p['avatar_url']?.toString();
                final unread = x['unread'] == true;
                return ListTile(
                  onTap: () => _open(x),
                  tileColor: _mSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: AmlFaceAvatar(radius: 25, backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null),
                  title: Text(name.isEmpty ? 'Membre AML' : name, style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                  subtitle: Text(
                    '${p['username']?.toString().isNotEmpty == true ? '@${p['username']}' : 'Membre AML'}${(x['last_message'] as Map?)?['created_at'] != null ? ' • ${_amlMessageTime((x['last_message'] as Map)['created_at'])}' : ''}',
                    style: const TextStyle(color: _mBlue, fontSize: 11),
                  ),
                  trailing: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [if ((x['last_message'] as Map?)?['created_at'] != null) Text(_amlMessageTime((x['last_message'] as Map)['created_at']), style: const TextStyle(color: Colors.white38, fontSize: 9)), const SizedBox(height: 4), unread ? const AmlFaceAvatar(radius: 5, backgroundColor: _mBlue) : const Icon(Icons.chevron_right, color: Colors.white24)]),
                );
              },
            ),
    ),
  );
}

class AmlMessageThreadScreen extends StatefulWidget {
  final String otherUserId;
  final Map<String, dynamic> profile;
  const AmlMessageThreadScreen({super.key, required this.otherUserId, required this.profile});
  @override State<AmlMessageThreadScreen> createState() => _AmlMessageThreadScreenState();
}

class _AmlMessageThreadScreenState extends State<AmlMessageThreadScreen> {
  final repo = MessagingRepository();
  final controller = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic> displayProfile = {};
  bool loading = true, sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { controller.dispose(); scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      displayProfile = widget.profile.isNotEmpty
          ? widget.profile
          : (await repo.profile(widget.otherUserId) ?? <String, dynamic>{});
      await repo.markThreadRead(widget.otherUserId);
      final data = await repo.thread(widget.otherUserId);
      if (!mounted) return;
      setState(() { messages = data; loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted) { setState(() => loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    }
  }

  Future<void> _send() async {
    final body = controller.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final sent = await repo.send(widget.otherUserId, body);
      controller.clear();
      if (mounted) setState(() => messages = [...messages, sent]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => sending = false); }
  }

  @override Widget build(BuildContext context) {
    final first = displayProfile['first_name']?.toString() ?? '';
    final last = displayProfile['last_name']?.toString() ?? '';
    final name = ('$first $last').trim();
    final avatar = displayProfile['avatar_url']?.toString();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _mBlack,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          AmlFaceAvatar(radius: 17, backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.white38) : null),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? 'Membre AML' : name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)), Text(displayProfile['username']?.toString().isNotEmpty == true ? '@${displayProfile['username']}' : '', style: const TextStyle(color: _mBlue, fontSize: 9))])),
        ]),
      ),
      body: Column(children: [
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator(color: _mBlue))
          : ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final mine = m['sender_id']?.toString() != widget.otherUserId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: mine ? _mBlue : _mSurface, borderRadius: BorderRadius.circular(17)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m['body']?.toString() ?? '', style: const TextStyle(height: 1.3)),
                        const SizedBox(height: 4),
                        Text(_amlMessageTime(m['created_at']), style: TextStyle(fontSize: 9, color: mine ? Colors.white70 : Colors.white38)),
                      ],
                    ),
                  ),
                );
              },
            )),
        SafeArea(top: false, child: Container(padding: const EdgeInsets.fromLTRB(10, 6, 10, 8), color: _mSurface, child: Row(children: [
          Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: InputDecoration(hintText: 'Écrire un message…', filled: true, fillColor: Colors.white.withValues(alpha: .06), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10)))),
          const SizedBox(width: 7),
          CircleAvatar(backgroundColor: _mBlue, child: IconButton(onPressed: sending ? null : _send, icon: sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, size: 18, color: Colors.white))),
        ]))),
      ]),
    );
  }
}

class AmlNewMessageScreen extends StatefulWidget {
  const AmlNewMessageScreen({super.key});
  @override State<AmlNewMessageScreen> createState() => _AmlNewMessageScreenState();
}

class _AmlNewMessageScreenState extends State<AmlNewMessageScreen> {
  final repo = MessagingRepository();
  final search = TextEditingController();
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> followers = [];
  bool loading = false;
  bool loadingFollowers = true;

  @override void initState() { super.initState(); _loadFollowers(); _search(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> _loadFollowers() async {
    try {
      final data = await repo.myFollowers();
      if (mounted) setState(() { followers = data; loadingFollowers = false; });
    } catch (_) {
      if (mounted) setState(() => loadingFollowers = false);
    }
  }

  Widget _memberTile(Map<String, dynamic> p) {
    final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final avatar = p['avatar_url']?.toString();
    return ListTile(
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AmlMessageThreadScreen(otherUserId: p['id'].toString(), profile: p))),
      tileColor: _mSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: AmlFaceAvatar(backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null),
      title: Text(name.isEmpty ? 'Membre AML' : name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(p['username']?.toString().isNotEmpty == true ? '@${p['username']}' : 'Membre AML', style: const TextStyle(color: _mBlue, fontSize: 10)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }

  Future<void> _search() async {
    setState(() => loading = true);
    try {
      final data = await repo.searchMembers(search.text);
      if (mounted) setState(() { members = data; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _mBlack,
    appBar: AppBar(title: const Text('Nouveau message', style: TextStyle(fontWeight: FontWeight.w900))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(controller: search, onChanged: (_) => _search(), onSubmitted: (_) => _search(), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher un membre…', filled: true, fillColor: _mSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))),
      if (loading) const LinearProgressIndicator(color: _mBlue, minHeight: 2),
      if (search.text.trim().isEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 8), child: Row(children: [const Icon(Icons.people_alt_outlined, color: _mBlue, size: 18), const SizedBox(width: 8), Text('TES CONTACTS (${followers.length})', style: const TextStyle(color: _mBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7))])),
        Expanded(child: loadingFollowers
          ? const Center(child: CircularProgressIndicator(color: _mBlue))
          : followers.isEmpty
            ? ListView(children: const [SizedBox(height: 25), Center(child: Text('Aucun contact pour le moment.', style: TextStyle(color: Colors.white54))), SizedBox(height: 20), Center(child: Text('Envoie une demande de suivi depuis le profil d’un membre : dès qu’il l’accepte, vous pouvez vous écrire.', style: TextStyle(color: Colors.white38, fontSize: 12)))])
            : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: followers.length, separatorBuilder: (_, __) => const SizedBox(height: 6), itemBuilder: (_, i) => _memberTile(followers[i]))),
      ] else
        Expanded(child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: members.length, separatorBuilder: (_, __) => const SizedBox(height: 6), itemBuilder: (_, i) => _memberTile(members[i]))),
    ]),
  );
}
