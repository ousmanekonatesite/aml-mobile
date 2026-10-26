import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../services/community_repository.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_screen.dart';
import '../predictions/predictions_screen.dart';
import '../profile/public_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets_url_media_preview.dart';
import '../../utils/aml_time.dart';
import '../../widgets_face_avatar.dart';
import '../../services/profile_repository.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/follow_requests_screen.dart';
import 'post_backgrounds.dart';
import 'reactions.dart';
import 'post_video.dart';

const Color _blue = Color(0xFF00AEEF), _black = Color(0xFF050505), _surface = Color(0xFF111111);
const Color _card = Color(0xFF121416);

class AmlCommunityScreen extends StatefulWidget {
  final String? initialPostId;
  final String? initialCommentId;
  const AmlCommunityScreen({super.key, this.initialPostId, this.initialCommentId});
  @override
  State<AmlCommunityScreen> createState() => _AmlCommunityScreenState();
}

class _AmlCommunityScreenState extends State<AmlCommunityScreen> {
  final repo = CommunityRepository();
  bool loading = true;
  List<Map<String, dynamic>> posts = [];
  String filter = 'all'; // all | following | saved
  Map<String, dynamic>? me;
  int? members;
  int? online;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMe();
    _loadStats();
  }

  String? get _myId => SupabaseService.client?.auth.currentUser?.id;

  Future<void> _loadMe() async {
    try {
      final p = await ProfileRepository().loadMine();
      if (mounted) setState(() => me = p);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final c = SupabaseService.client;
    if (c == null) return;
    try {
      final r = await c.rpc('aml_community_stats');
      if (r is Map && mounted) {
        setState(() {
          members = (r['members'] as num?)?.toInt();
          online = (r['online'] as num?)?.toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadStats()]);
  }

  Future<void> _load() async {
    if (mounted && posts.isEmpty) setState(() => loading = true);
    try {
      final d = await repo.posts();
      if (!mounted) return;
      setState(() {
        posts = d;
        loading = false;
      });
      if (widget.initialPostId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final exists = posts.any((p) => p['id'].toString() == widget.initialPostId);
          if (exists) {
            final post = posts.firstWhere((p) => p['id'].toString() == widget.initialPostId);
            showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              backgroundColor: _surface,
              builder: (_) => _CommentsSheet(postId: post['id'].toString(), initialCommentId: widget.initialCommentId, msg: _msg),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _msg(e);
      }
    }
  }

  void _msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
  }

  List<Map<String, dynamic>> get _visible {
    switch (filter) {
      case 'following':
        return posts.where((p) => p['following_author'] == true || p['author_id']?.toString() == _myId).toList();
      case 'saved':
        return posts.where((p) => p['bookmarked_by_me'] == true).toList();
      default:
        return posts;
    }
  }

  Future<bool> _submit(String text, List<XFile> images, XFile? video, int videoSeconds, String? background) async {
    if (SupabaseService.client?.auth.currentUser == null) {
      if (!mounted) return false;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAuthScreen()));
      if (mounted) await _load();
      return false;
    }
    try {
      final List<Map<String, String>> media;
      if (video != null) {
        final uploaded = await repo.uploadCommunityVideo(file: File(video.path), fileName: video.name);
        media = [{...uploaded, 'duration_seconds': '$videoSeconds'}];
      } else {
        media = await Future.wait(images.map((f) async => repo.uploadCommunityImage(bytes: await f.readAsBytes(), fileName: f.name)));
      }
      final newPost = await repo.createPost(text, media: media, backgroundKey: (images.isEmpty && video == null) ? background : null);
      if (mounted) setState(() => posts = [newPost, ...posts]);
      return true;
    } catch (e) {
      _msg(e);
      return false;
    }
  }

  Future<void> _openComposer({bool photo = false, bool video = false}) async {
    if (SupabaseService.client?.auth.currentUser == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAuthScreen()));
      if (mounted) {
        await _loadMe();
        await _load();
      }
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposerSheet(me: me, startWithPhoto: photo, startWithVideo: video, onSubmit: _submit),
    );
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      backgroundColor: _black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _CommunityHeader(members: members, online: online, canPop: Navigator.canPop(context))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _ShortcutChip(icon: Icons.emoji_events_rounded, label: 'Pronos', onTap: () => _push(const AmlPredictionsScreen())),
                    _ShortcutChip(icon: Icons.chat_bubble_rounded, label: 'Messages', onTap: () => _push(const AmlMessagesScreen())),
                    _ShortcutChip(icon: Icons.person_add_alt_1_rounded, label: 'Demandes', onTap: () => _push(const AmlFollowRequestsScreen())),
                    _ShortcutChip(icon: Icons.notifications_rounded, label: 'Notifications', onTap: () => _push(const AmlNotificationsScreen())),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _ComposerTeaser(me: me, onText: () => _openComposer(), onPhoto: () => _openComposer(photo: true), onVideo: () => _openComposer(video: true))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Row(children: [
                  _FilterPill(label: 'Pour toi', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Mes abonnés', selected: filter == 'following', onTap: () => setState(() => filter = 'following')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Sauvegardés', selected: filter == 'saved', onTap: () => setState(() => filter = 'saved')),
                ]),
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator(color: _blue))))
            else if (list.isEmpty)
              SliverToBoxAdapter(child: _EmptyFeed(filter: filter))
            else
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _PostCard(key: ValueKey(list[i]['id']), post: list[i], onRefresh: _load, msg: _msg),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  final int? members;
  final int? online;
  final bool canPop;
  const _CommunityHeader({this.members, this.online, this.canPop = false});

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      if (online != null && online! > 0) _StatPill(color: const Color(0xFF2ECC71), text: '$online en ligne'),
      if (members != null && members! > 0) _StatPill(color: Colors.white, text: '$members membres', icon: Icons.groups_2_rounded),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00AEEF), Color(0xFF0067A0), Color(0xFF031A2A)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: _blue.withOpacity(.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(right: -14, top: -10, child: Icon(Icons.sports_mma_rounded, size: 110, color: Colors.white.withOpacity(.10))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (canPop)
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
            const Text('AML COMMUNITY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: .6)),
          ]),
          const SizedBox(height: 6),
          const Text('Fans, fighters, coachs et passionnés du MMA africain.\nPartage, réagis et suis les combats en direct.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: pills),
          ],
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Color color;
  final String text;
  final IconData? icon;
  const _StatPill({required this.color, required this.text, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(.28), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) Icon(icon, size: 14, color: color) else Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _ShortcutChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutChip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: _card,
      shape: StadiumBorder(side: BorderSide(color: _blue.withOpacity(.35))),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: _blue),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _blue : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: selected ? Colors.white : Colors.white60)),
    ),
  );
}

class _ComposerTeaser extends StatelessWidget {
  final Map<String, dynamic>? me;
  final VoidCallback onText, onPhoto, onVideo;
  const _ComposerTeaser({this.me, required this.onText, required this.onPhoto, required this.onVideo});

  @override
  Widget build(BuildContext context) {
    final avatar = me?['avatar_url']?.toString();
    final first = (me?['first_name'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        InkWell(
          onTap: onText,
          borderRadius: BorderRadius.circular(16),
          child: Row(children: [
            AmlFaceAvatar(radius: 20, backgroundColor: const Color(0xFF1B2A33), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: const Icon(Icons.person, color: Colors.white38)),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(22)),
                child: Text(first.isEmpty ? 'Quoi de neuf dans la communauté ?' : 'Quoi de neuf, $first ?', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _TeaserAction(icon: Icons.palette_rounded, color: const Color(0xFFEC008C), label: 'Texte', onTap: onText)),
          const SizedBox(width: 8),
          Expanded(child: _TeaserAction(icon: Icons.photo_library_rounded, color: const Color(0xFF38EF7D), label: 'Photos', onTap: onPhoto)),
          const SizedBox(width: 8),
          Expanded(child: _TeaserAction(icon: Icons.videocam_rounded, color: const Color(0xFFFFB020), label: 'Vidéo', onTap: onVideo)),
        ]),
      ]),
    );
  }
}

class _TeaserAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _TeaserAction({required this.icon, required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  final String filter;
  const _EmptyFeed({required this.filter});
  @override
  Widget build(BuildContext context) {
    final text = filter == 'following'
        ? 'Aucune publication de tes abonnés pour le moment.\nEnvoie des demandes de suivi pour remplir ton fil.'
        : filter == 'saved'
            ? 'Aucune publication sauvegardée.\nAppuie sur le marque-page d’un post pour le retrouver ici.'
            : 'Aucune publication pour le moment.\nSois le premier à publier !';
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(children: [
        Icon(Icons.forum_rounded, size: 52, color: _blue.withOpacity(.5)),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, height: 1.5)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte de publication
// ---------------------------------------------------------------------------
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onRefresh;
  final void Function(Object) msg;
  const _PostCard({super.key, required this.post, required this.onRefresh, required this.msg});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool pop = false;
  final GlobalKey _reactKey = GlobalKey();

  Future<void> _comments() async {
    final r = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => _CommentsSheet(postId: widget.post['id'].toString(), msg: widget.msg),
    );
    if (r != null && mounted) {
      widget.post['comment_count'] = r;
      setState(() {});
    }
  }

  Future<void> _follow() async {
    try {
      final authorId = widget.post['author_id'].toString();
      final fs = (widget.post['follow_status'] ?? (widget.post['following_author'] == true ? 'connected' : 'none')).toString();
      final next = await CommunityRepository().followAction(authorId, fs);
      widget.post['follow_status'] = next;
      widget.post['following_author'] = next == 'connected';
      if (next == 'pending_out' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée. Tu seras abonné dès qu’elle sera acceptée.')));
      }
      setState(() {});
    } catch (e) {
      widget.msg(e);
    }
  }

  Future<void> _save() async {
    try {
      final v = await CommunityRepository().toggleBookmark(widget.post['id'].toString(), widget.post['bookmarked_by_me'] == true);
      widget.post['bookmarked_by_me'] = v;
      setState(() {});
    } catch (e) {
      widget.msg(e);
    }
  }

  Future<void> _delete() async {
    try {
      await CommunityRepository().deletePost(widget.post['id'].toString());
      widget.onRefresh();
    } catch (e) {
      widget.msg(e);
    }
  }

  void _apply(Map<String, dynamic> p, String? key, Map<String, dynamic> counts) {
    p['my_reaction'] = key;
    p['reactions'] = counts;
    p['liked_by_me'] = key != null;
    p['like_count'] = counts.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0));
  }

  /// Une réaction par membre : choisir la même la retire, en choisir une autre la remplace.
  Future<void> _setReaction(String? key) async {
    final p = widget.post;
    final prev = p['my_reaction']?.toString();
    if (prev == key) return;
    final oldCounts = Map<String, dynamic>.from(p['reactions'] ?? {});
    final counts = Map<String, dynamic>.from(oldCounts);
    if (prev != null) {
      final n = ((counts[prev] as num?)?.toInt() ?? 1) - 1;
      if (n <= 0) {
        counts.remove(prev);
      } else {
        counts[prev] = n;
      }
    }
    if (key != null) counts[key] = ((counts[key] as num?)?.toInt() ?? 0) + 1;
    setState(() {
      _apply(p, key, counts);
      pop = key != null;
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => pop = false);
    });
    try {
      await CommunityRepository().setReaction(p['id'].toString(), key);
    } catch (e) {
      if (mounted) setState(() => _apply(p, prev, oldCounts));
      widget.msg(e);
    }
  }

  void _quickReact() => _setReaction(widget.post['my_reaction'] == null ? 'love' : null);

  Future<void> _openPicker() async {
    final box = _reactKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final current = widget.post['my_reaction']?.toString();
    final key = await showReactionPicker(context, pos & box.size, current: current);
    if (key != null) _setReaction(key == current ? null : key);
  }

  void _openProfile() => Navigator.push(context, MaterialPageRoute(builder: (_) => AmlPublicProfileScreen(userId: widget.post['author_id'].toString())));

  void _openViewer(List<String> urls, int index) {
    Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => _MediaViewer(urls: urls, index: index)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final profile = Map<String, dynamic>.from(p['author_profile'] ?? {});
    final name = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
    final avatar = profile['avatar_url']?.toString();
    final mediaList = List<Map<String, dynamic>>.from(p['post_media'] ?? []);
    Map<String, dynamic>? video;
    for (final m in mediaList) {
      if (m['media_type']?.toString() == 'video') {
        video = m;
        break;
      }
    }
    final urls = mediaList.where((m) => m['media_type']?.toString() != 'video').map((m) => m['media_url'].toString()).toList();
    final content = (p['content'] ?? '').toString();
    final bg = (urls.isEmpty && video == null) ? postBackgroundFor(p['background_key']) : null;
    final myReaction = p['my_reaction']?.toString();
    final myEmoji = reactionFor(myReaction)?.emoji;
    final saved = p['bookmarked_by_me'] == true;
    final fs = (p['follow_status'] ?? (p['following_author'] == true ? 'connected' : 'none')).toString();
    final mine = SupabaseService.client?.auth.currentUser?.id == p['author_id'];
    final urlMatch = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(content);
    final username = (profile['username'] ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(.07))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
          child: Row(children: [
            GestureDetector(
              onTap: _openProfile,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF00AEEF), Color(0xFF8E2DE2)])),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _card),
                  child: AmlFaceAvatar(radius: 19, backgroundColor: const Color(0xFF1B2A33), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: const Icon(Icons.person, color: Colors.white38)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _openProfile,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name.isEmpty ? 'Membre AML' : name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                    if (profile['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 15, color: _blue)),
                  ]),
                  Text(
                    [if (username.isNotEmpty) '@$username', amlFormatDateTime(p['created_at'])].where((e) => e.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                ]),
              ),
            ),
            if (!mine)
              GestureDetector(
                onTap: fs == 'connected' ? null : _follow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: fs == 'connected' || fs == 'pending_out' ? Colors.white.withOpacity(.07) : _blue.withOpacity(.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    fs == 'connected' ? 'Suivi' : fs == 'pending_out' ? 'Demande envoyée' : fs == 'pending_in' ? 'Accepter' : '+ Suivre',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fs == 'connected' || fs == 'pending_out' ? Colors.white38 : _blue),
                  ),
                ),
              ),
            if (mine)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onSelected: (v) {
                  if (v == 'delete') _delete();
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Supprimer'))],
              ),
          ]),
        ),
        GestureDetector(
          onDoubleTap: myReaction == null ? () => _setReaction('love') : null,
          behavior: HitTestBehavior.opaque,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (bg != null && content.isNotEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: AmlBackgroundPostText(text: content, background: bg))
            else if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(content, style: TextStyle(color: Colors.white.withOpacity(.9), height: 1.45, fontSize: 14.5)),
                  if (urlMatch != null) AmlUrlMediaPreview(url: urlMatch.group(0)!.replaceAll(RegExp(r'[),.!?]+$'), '')),
                ]),
              ),
            if (urls.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _PostMedia(urls: urls, onOpen: (i) => _openViewer(urls, i))),
            if (video != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AmlVideoTile(
                  seconds: (video['duration_seconds'] as num?)?.toInt(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => AmlVideoPlayerScreen(url: video!['media_url'].toString()))),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(children: [
            GestureDetector(
              key: _reactKey,
              behavior: HitTestBehavior.opaque,
              onTap: _quickReact,
              onLongPress: _openPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  AnimatedScale(
                    scale: pop ? 1.45 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: myEmoji != null ? Text(myEmoji, style: const TextStyle(fontSize: 22)) : const Icon(Icons.favorite_border_rounded, size: 23, color: Colors.white60),
                  ),
                  const SizedBox(width: 6),
                  AmlReactionSummary(counts: Map<String, dynamic>.from(p['reactions'] ?? {})),
                ]),
              ),
            ),
            InkWell(
              onTap: _openPicker,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_reaction_outlined, size: 21, color: Colors.white54)),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _comments,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.mode_comment_outlined, size: 21, color: Colors.white60),
                  const SizedBox(width: 6),
                  Text('${p['comment_count'] ?? 0}', style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const Spacer(),
            IconButton(onPressed: _save, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 23, color: saved ? _blue : Colors.white60)),
          ]),
        ),
      ]),
    );
  }
}

/// Photos d'une publication : 1 grande image, 2 côte à côte, 3 en mosaïque, 4+ en grille avec « +N ».
class _PostMedia extends StatelessWidget {
  final List<String> urls;
  final void Function(int) onOpen;
  const _PostMedia({required this.urls, required this.onOpen});

  Widget _tile(int i, {BoxFit fit = BoxFit.cover, String? overlay}) {
    return GestureDetector(
      onTap: () => onOpen(i),
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: urls[i],
          fit: fit,
          alignment: Alignment.topCenter,
          placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A1A1A)),
          errorWidget: (_, __, ___) => const ColoredBox(color: Colors.white10, child: Center(child: Icon(Icons.broken_image, color: Colors.white38))),
        ),
        if (overlay != null) ColoredBox(color: Colors.black54, child: Center(child: Text(overlay, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = urls.length;
    Widget content;
    if (n == 1) {
      content = AspectRatio(aspectRatio: 4 / 5, child: _tile(0));
    } else if (n == 2) {
      content = SizedBox(height: 280, child: Row(children: [Expanded(child: _tile(0)), const SizedBox(width: 3), Expanded(child: _tile(1))]));
    } else if (n == 3) {
      content = SizedBox(
        height: 300,
        child: Row(children: [
          Expanded(flex: 3, child: _tile(0)),
          const SizedBox(width: 3),
          Expanded(flex: 2, child: Column(children: [Expanded(child: _tile(1)), const SizedBox(height: 3), Expanded(child: _tile(2))])),
        ]),
      );
    } else {
      final extra = n - 4;
      content = SizedBox(
        height: 300,
        child: Column(children: [
          Expanded(child: Row(children: [Expanded(child: _tile(0)), const SizedBox(width: 3), Expanded(child: _tile(1))])),
          const SizedBox(height: 3),
          Expanded(child: Row(children: [Expanded(child: _tile(2)), const SizedBox(width: 3), Expanded(child: _tile(3, overlay: extra > 0 ? '+$extra' : null))])),
        ]),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: content);
  }
}

class _MediaViewer extends StatefulWidget {
  final List<String> urls;
  final int index;
  const _MediaViewer({required this.urls, required this.index});
  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController controller = PageController(initialPage: widget.index);
  late int current = widget.index;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: widget.urls.length > 1 ? Text('${current + 1} / ${widget.urls.length}', style: const TextStyle(fontSize: 14)) : null,
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: CachedNetworkImage(imageUrl: widget.urls[i], fit: BoxFit.contain, placeholder: (_, __) => const CircularProgressIndicator(color: _blue))),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composeur : 1) fond coloré  2) texte  3) publier. Les posts avec photos n'ont pas de fond.
// ---------------------------------------------------------------------------
class _ComposerSheet extends StatefulWidget {
  final Map<String, dynamic>? me;
  final bool startWithPhoto;
  final bool startWithVideo;
  final Future<bool> Function(String text, List<XFile> images, XFile? video, int videoSeconds, String? background) onSubmit;
  const _ComposerSheet({this.me, this.startWithPhoto = false, this.startWithVideo = false, required this.onSubmit});
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final text = TextEditingController();
  final picker = ImagePicker();
  List<XFile> images = [];
  XFile? video;
  int videoSeconds = 0;
  String? notice;
  String? bg = kPostBackgrounds.first.key;
  bool posting = false, emoji = false;
  String url = '';

  @override
  void initState() {
    super.initState();
    text.addListener(_onText);
    if (widget.startWithPhoto) WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    if (widget.startWithVideo) WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideo());
  }

  @override
  void dispose() {
    text.removeListener(_onText);
    text.dispose();
    super.dispose();
  }

  void _onText() {
    final m = RegExp(r'(https?://[^\s]+)', caseSensitive: false).firstMatch(text.text);
    final next = m?.group(1)?.replaceAll(RegExp(r'[),.!?]+$'), '') ?? '';
    setState(() => url = next);
  }

  Future<void> _pick() async {
    final files = await picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (files.isNotEmpty && mounted) {
      setState(() {
        images = files.take(8).toList();
        video = null;
        videoSeconds = 0;
        notice = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF15181B),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Vidéo · 3 minutes maximum', style: TextStyle(fontWeight: FontWeight.w900)))),
          ListTile(leading: const Icon(Icons.video_library_outlined, color: _blue), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.videocam_outlined, color: _blue), title: const Text('Filmer maintenant'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 3));
    if (file == null || !mounted) return;
    final size = await File(file.path).length();
    if (size > kMaxPostVideoBytes) {
      if (mounted) setState(() => notice = 'Vidéo trop lourde : ${(size / 1048576).toStringAsFixed(0)} Mo (50 Mo maximum).');
      return;
    }
    final secs = await probeVideoSeconds(file.path);
    if (!mounted) return;
    if (secs == null) {
      setState(() => notice = 'Impossible de lire cette vidéo.');
      return;
    }
    if (secs > kMaxPostVideoSeconds) {
      setState(() => notice = 'Vidéo trop longue : ${formatVideoDuration(secs)}. La limite est de 3 minutes.');
      return;
    }
    setState(() {
      video = file;
      videoSeconds = secs < 1 ? 1 : secs;
      images = [];
      notice = null;
    });
  }

  bool get _canPublish => !posting && (text.text.trim().isNotEmpty || images.isNotEmpty || video != null);

  Future<void> _publish() async {
    setState(() => posting = true);
    final ok = await widget.onSubmit(text.text.trim(), images, video, videoSeconds, (images.isEmpty && video == null) ? bg : null);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => posting = false);
    }
  }

  Widget _swatch(String? key) {
    final data = postBackgroundFor(key);
    final selected = bg == key;
    return GestureDetector(
      onTap: () => setState(() => bg = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        margin: const EdgeInsets.only(right: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: data == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors),
          color: data == null ? const Color(0xFF1C1C1C) : null,
          border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 3 : 1),
        ),
        child: data == null ? const Text('Aa', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)) : (selected ? Icon(Icons.check, size: 18, color: data.text) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plain = images.isNotEmpty || video != null;
    final data = plain ? null : postBackgroundFor(bg);
    final avatar = widget.me?['avatar_url']?.toString();
    final fullName = '${widget.me?['first_name'] ?? ''} ${widget.me?['last_name'] ?? ''}'.trim();
    final fs = postBackgroundFontSize(text.text.length);
    return Container(
      height: MediaQuery.of(context).size.height * .94,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Color(0xFF0B0D0F), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 4),
          child: Row(children: [
            IconButton(onPressed: posting ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            const Expanded(child: Text('Nouvelle publication', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ElevatedButton(
              onPressed: _canPublish ? _publish : null,
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22)),
              child: posting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publier', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        if (posting) const LinearProgressIndicator(minHeight: 2, color: _blue, backgroundColor: Colors.transparent),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (notice != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                  child: Text(notice!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
              Row(children: [
                AmlFaceAvatar(radius: 18, backgroundColor: const Color(0xFF1B2A33), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: const Icon(Icons.person, color: Colors.white38)),
                const SizedBox(width: 10),
                Text(fullName.isEmpty ? 'Membre AML' : fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 14),
              if (!plain) ...[
                const Text('1 · CHOISIS UN FOND', style: TextStyle(color: _blue, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
                SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, children: [..._palette(), _swatch(null)])),
                const SizedBox(height: 14),
                const Text('2 · ÉCRIS TON MESSAGE', style: TextStyle(color: _blue, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: _blue.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: _blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Les publications avec photos ou vidéo n’ont pas de fond coloré.', style: TextStyle(fontSize: 11.5, color: Colors.white70))),
                  ]),
                ),
              ],
              if (data != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 230),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors), borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: text,
                    textAlign: TextAlign.center,
                    maxLength: 300,
                    maxLines: null,
                    cursorColor: data.text,
                    style: TextStyle(color: data.text, fontSize: fs, fontWeight: FontWeight.w800, height: 1.25),
                    decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: 'Écris ton message…', hintStyle: TextStyle(color: data.text.withOpacity(.55), fontWeight: FontWeight.w700)),
                  ),
                )
              else
                TextField(
                  controller: text,
                  minLines: !plain ? 6 : 3,
                  maxLines: 12,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  decoration: InputDecoration(
                    hintText: !plain ? 'Quoi de neuf dans la communauté ?' : 'Ajoute une légende…',
                    filled: true,
                    fillColor: Colors.white.withOpacity(.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              if (url.isNotEmpty && data == null) Padding(padding: const EdgeInsets.only(top: 10), child: AmlUrlMediaPreview(url: url, compact: true)),
              if (video != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF14202A), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.play_circle_fill_rounded, size: 34, color: _blue)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(video!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(posting ? 'Envoi de la vidéo… ne ferme pas cette fenêtre.' : 'Durée ${formatVideoDuration(videoSeconds)} • 3 minutes maximum', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ]),
                    ),
                    if (!posting) IconButton(onPressed: () => setState(() { video = null; videoSeconds = 0; }), icon: const Icon(Icons.close_rounded)),
                  ]),
                ),
              ],
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(images[i].path), width: 96, height: 96, fit: BoxFit.cover, alignment: Alignment.topCenter)),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => images.removeAt(i)),
                          child: const CircleAvatar(radius: 11, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 13)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
        if (emoji)
          SizedBox(
            height: 260,
            child: EmojiPicker(
              textEditingController: text,
              config: const Config(locale: Locale('fr'), height: 260, emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28)),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 16, 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
          child: Row(children: [
            IconButton(onPressed: () => setState(() => emoji = !emoji), icon: Icon(emoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: _blue)),
            IconButton(onPressed: _pick, icon: const Icon(Icons.photo_library_outlined, color: _blue)),
            IconButton(onPressed: _pickVideo, icon: const Icon(Icons.videocam_outlined, color: _blue)),
            const Spacer(),
            if (data != null) Text('${text.text.length}/300', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _palette() => kPostBackgrounds.map((b) => _swatch(b.key)).toList();
}

class _MediaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  const _MediaGrid({required this.media});

  @override
  Widget build(BuildContext c) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: media.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: media.length == 1 ? 1 : 2,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: media[i]['media_url'].toString(),
            fit: BoxFit.cover, alignment: Alignment.topCenter,
            errorWidget: (_, __, ___) => const ColoredBox(
              color: Colors.white10,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
          ),
        );
      },
    );
  }
}
class _Btn extends StatelessWidget{final IconData icon;final String label;final bool active;final VoidCallback onTap;const _Btn({required this.icon,required this.label,required this.onTap,this.active=false});@override Widget build(BuildContext c)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(horizontal:3,vertical:5),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:20,color:active?Colors.redAccent:Colors.white54),const SizedBox(width:5),Text(label,style:const TextStyle(color:Colors.white54,fontSize:12))])));}
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String? initialCommentId;
  final void Function(Object) msg;
  const _CommentsSheet({required this.postId, this.initialCommentId, required this.msg});
  @override State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final repo = CommunityRepository();
  final text = TextEditingController();
  final picker = ImagePicker();
  List<Map<String,dynamic>> rows = [];
  List<XFile> images = [];
  Map<String,dynamic>? replyTo;
  bool loading = true, sending = false, emoji = false; String previewUrl = '';

  @override void initState() { super.initState(); text.addListener(_textChanged); _load(); }
  @override void dispose() { text.removeListener(_textChanged); text.dispose(); super.dispose(); }
  void _textChanged(){final m=RegExp(r'(https?://[^\s]+)',caseSensitive:false).firstMatch(text.text);final next=m?.group(1)?.replaceAll(RegExp(r'[),.!?]+$'), '')??'';if(next!=previewUrl&&mounted)setState(()=>previewUrl=next);}
  Future<void> _load() async {
    try {
      final r = await repo.comments(widget.postId);
      if (mounted) setState(() { rows = r; loading = false; });
    } catch (e) { if (mounted) { setState(() => loading = false); widget.msg(e); } }
  }
  Future<void> _pick() async {
    final f = await picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (mounted && f.isNotEmpty) setState(() => images = f.take(6).toList());
  }
  Future<void> _send() async {
    if (text.text.trim().isEmpty && images.isEmpty) return;
    setState(() => sending = true);
    try {
      final urls = <Map<String,String>>[];
      for (final f in images) urls.add(await repo.uploadCommunityImage(bytes: await f.readAsBytes(), fileName: f.name));
      await repo.addComment(widget.postId, text.text, parentCommentId: replyTo?['id']?.toString(), media: urls);
      // Reload the list so the newly created comment also receives its real
      // author profile instead of temporarily falling back to "Membre AML".
      final refreshed = await repo.comments(widget.postId);
      text.clear();
      if (mounted) setState(() { images = []; replyTo = null; previewUrl = ''; rows = refreshed; });
    } catch (e) { widget.msg(e); } finally { if (mounted) setState(() => sending = false); }
  }
  String _author(Map<String,dynamic> x) {
    final p = Map<String,dynamic>.from(x['author_profile'] ?? {});
    final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final display = p['display_name']?.toString().trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = p['username']?.toString().trim() ?? '';
    return username.isNotEmpty ? '@$username' : 'Membre AML';
  }
  List<Map<String,dynamic>> _children(String? parentId) => rows.where((x) => (x['parent_comment_id']?.toString()) == parentId).toList();

  Widget _comment(Map<String,dynamic> x, {int depth = 0}) {
    final profile = Map<String,dynamic>.from(x['author_profile'] ?? {});
    final avatar = profile['avatar_url']?.toString();
    final username = profile['username']?.toString().trim();
    final media = List<Map<String,dynamic>>.from(x['comment_media'] ?? []);
    final children = _children(x['id'].toString());
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 18, bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: x['id']?.toString() == widget.initialCommentId ? _blue.withValues(alpha:.18) : (depth == 0 ? Colors.white.withValues(alpha:.04) : Colors.white.withValues(alpha:.025)),
          borderRadius: BorderRadius.circular(14),
          border: x['id']?.toString() == widget.initialCommentId ? Border.all(color: _blue, width: 2) : (depth > 0 ? Border(left: BorderSide(color:_blue.withValues(alpha:.35), width:2)) : null),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AmlFaceAvatar(radius: 17, backgroundColor: const Color(0xFF17232A), image: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, size:18, color:Colors.white38) : null),
            const SizedBox(width:8),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(_author(x), style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
              Text(username != null && username.isNotEmpty ? '@$username' : 'Membre AML', style:const TextStyle(color:_blue,fontWeight:FontWeight.w700,fontSize:10)),
              if (amlFormatDateTime(x['created_at']).isNotEmpty) Text(amlFormatDateTime(x['created_at']), style:const TextStyle(color:Colors.white38,fontSize:10)),
            ])),
          ]),
          if ((x['body']?.toString() ?? '').isNotEmpty) ...[Padding(padding:const EdgeInsets.only(top:8),child:Text(x['body'].toString(),style:const TextStyle(height:1.35))),if(RegExp(r'https?://[^\s]+',caseSensitive:false).hasMatch(x['body'].toString())) AmlUrlMediaPreview(url:RegExp(r'https?://[^\s]+',caseSensitive:false).firstMatch(x['body'].toString())!.group(0)!.replaceAll(RegExp(r'[),.!?]+$'), ''))],
          if (media.isNotEmpty) Padding(padding:const EdgeInsets.only(top:7),child:_MediaGrid(media:media)),
          const SizedBox(height:4),
          TextButton.icon(
            onPressed: () { setState(() { replyTo = x; emoji = false; }); FocusScope.of(context).requestFocus(FocusNode()); },
            icon: const Icon(Icons.reply_rounded, size:16, color:_blue),
            label: const Text('Répondre', style:TextStyle(color:_blue,fontSize:11,fontWeight:FontWeight.w800)),
            style: TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:2,vertical:2),minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),
          ),
          ...children.map((child) => _comment(child, depth: depth + 1)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final roots = _children(null);
    final replyName = replyTo == null ? null : _author(replyTo!);
    return SafeArea(
      top:false,
      child:SizedBox(
        height:(MediaQuery.of(c).size.height*.82).clamp(320.0, MediaQuery.of(c).size.height - MediaQuery.of(c).viewInsets.bottom).toDouble(),
        child:Column(children:[
          Padding(padding:const EdgeInsets.all(14),child:Row(children:[
            const Expanded(child:Text('Commentaires',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),
            if(rows.isNotEmpty) Text('${rows.length}',style:const TextStyle(color:_blue,fontWeight:FontWeight.w900)),
            IconButton(onPressed:()=>Navigator.pop(context,rows.length),icon:const Icon(Icons.close)),
          ])),
          Expanded(child:loading
            ? const Center(child:CircularProgressIndicator(color:_blue))
            : roots.isEmpty ? const Center(child:Text('Aucun commentaire.',style:TextStyle(color:Colors.white54)))
            : ListView(padding:const EdgeInsets.symmetric(horizontal:12),children:roots.map((x)=>_comment(x)).toList())),
          if (replyTo != null) Container(padding:const EdgeInsets.fromLTRB(13,7,8,4),color:_blue.withValues(alpha:.08),child:Row(children:[
            const Icon(Icons.reply_rounded,color:_blue,size:17),const SizedBox(width:7),Expanded(child:Text('Réponse à $replyName',style:const TextStyle(color:_blue,fontSize:11,fontWeight:FontWeight.w800))),
            IconButton(onPressed:()=>setState(()=>replyTo=null),icon:const Icon(Icons.close,size:17,color:Colors.white54)),
          ])),
          if(images.isNotEmpty) SizedBox(height:66,child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),scrollDirection:Axis.horizontal,itemCount:images.length,itemBuilder:(_,i)=>Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(9),child:Image.file(File(images[i].path),width:58,height:56,fit:BoxFit.cover, alignment: Alignment.topCenter)),Positioned(right:0,top:0,child:GestureDetector(onTap:()=>setState(()=>images.removeAt(i)),child:const CircleAvatar(radius:9,child:Icon(Icons.close,size:11))))]),separatorBuilder:(_,__)=>const SizedBox(width:6))),
          if(emoji) SizedBox(height:240,child:EmojiPicker(textEditingController:text,onEmojiSelected:(_,e)=>text.text+=e.emoji,config:const Config(locale:Locale('fr'),height:240,emojiViewConfig:EmojiViewConfig(emojiSizeMax:26)))),
          AnimatedPadding(padding:EdgeInsets.only(bottom:MediaQuery.of(c).viewInsets.bottom),duration:const Duration(milliseconds:120),curve:Curves.easeOut,child:Container(padding:const EdgeInsets.fromLTRB(8,5,8,8),child:Row(children:[
            IconButton(onPressed:()=>setState(()=>emoji=!emoji),icon:Icon(emoji?Icons.keyboard:Icons.emoji_emotions_outlined,color:_blue)),
            IconButton(onPressed:_pick,icon:const Icon(Icons.photo_outlined,color:_blue)),
            Expanded(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:text,minLines:1,maxLines:3,decoration:InputDecoration(hintText:replyTo==null?'Écrire un commentaire…':'Écrire une réponse…',filled:true,fillColor:Colors.white.withValues(alpha:.06),border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:10))),if(previewUrl.isNotEmpty) AmlUrlMediaPreview(url:previewUrl,compact:true)])),
            IconButton(onPressed:sending?null:_send,icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:_blue)):const Icon(Icons.send,color:_blue)),
          ]))),
        ]),
      ),
    );
  }
}
class _Empty extends StatelessWidget{const _Empty();@override Widget build(BuildContext c)=>const Padding(padding:EdgeInsets.all(35),child:Center(child:Text('Aucune publication pour le moment.',style:TextStyle(color:Colors.white54))));}
