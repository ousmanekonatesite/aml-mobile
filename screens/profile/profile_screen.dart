import 'package:flutter/material.dart';
import '../../services/profile_repository.dart';
import '../../services/supabase_service.dart';
import '../auth/auth_screen.dart';
import '../community/community_screen.dart';
import 'edit_profile_screen.dart';
import '../shop/orders_screen.dart';
import '../admin/admin_screen.dart';
import '../wallet/wallet_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import 'my_tickets_screen.dart';
import 'my_badges_screen.dart';
import '../../services/app_update_service.dart';
import 'profile_settings_screen.dart';
import '../../widgets_face_avatar.dart';

const Color _pBlue = Color(0xFF00AEEF);
const Color _pBlack = Color(0xFF050505);
const Color _pSurface = Color(0xFF111111);

class AmlProfileScreen extends StatefulWidget {
  const AmlProfileScreen({super.key});

  @override
  State<AmlProfileScreen> createState() => _AmlProfileScreenState();
}

class _AmlProfileScreenState extends State<AmlProfileScreen> {
  final repo = ProfileRepository();
  Map<String, dynamic>? profile;
  int unread = 0;
  bool loading = true;

  bool get connected => SupabaseService.client?.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!connected) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final results = await Future.wait([repo.loadMine(), repo.unreadNotifications()]);
    if (!mounted) return;
    setState(() {
      profile = results[0] as Map<String, dynamic>?;
      unread = results[1] as int;
      loading = false;
    });
  }

  Future<void> _openAuth() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAuthScreen()));
    if (mounted) {
      setState(() => loading = true);
      await _load();
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.client?.auth.signOut();
    if (mounted) {
      setState(() {
        profile = null;
        unread = 0;
        loading = false;
      });
    }
  }

  Future<bool> _isStaff() async {
    final c = SupabaseService.client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return false;
    try {
      final row = await c.from('profiles').select('role,is_suspended').eq('id', user.id).maybeSingle();
      final role = row?['role']?.toString();
      return row != null &&
          row['is_suspended'] != true &&
          ['editor','moderator','media_manager','shop_manager','admin','super_admin'].contains(role);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(backgroundColor: _pBlack, body: Center(child: CircularProgressIndicator(color: _pBlue)));
    }

    if (!connected) {
      return _GuestProfile(onAuth: _openAuth);
    }

    final first = profile?['first_name']?.toString() ?? '';
    final last = profile?['last_name']?.toString() ?? '';
    final fullName = ('$first $last').trim();
    final username = profile?['username']?.toString();
    final type = _profileType(profile?['profile_type']?.toString());
    final avatar = profile?['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: _pBlack,
      appBar: AppBar(
        title: const Text('Mon espace', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          _BadgeIcon(
            icon: Icons.notifications_none,
            count: unread,
            onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlNotificationsScreen())); if (mounted) await _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _pBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _ProfileHeader(
              avatar: avatar,
              name: fullName.isEmpty ? 'Membre AML' : fullName,
              username: username,
              type: type,
              city: profile?['city']?.toString(),
              unread: unread,
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: 'COMMUNAUTÉ'),
            _ProfileTile(
              icon: Icons.forum_outlined,
              title: 'AML Community',
              subtitle: 'Publications, discussions et membres',
              badge: null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlCommunityScreen())),
            ),
            _ProfileTile(
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              subtitle: 'Discussions privées AML',
              badge: null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMessagesScreen())),
            ),
            _ProfileTile(
              icon: Icons.notifications_none,
              title: 'Notifications',
              subtitle: 'Actualités et activités de ton compte',
              badge: unread > 0 ? unread.toString() : null,
              onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlNotificationsScreen())); if (mounted) await _load(); },
            ),
            const SizedBox(height: 8),
            _SectionTitle(title: 'MON PROFIL'),
            _ProfileTile(
              icon: Icons.person_outline,
              title: 'Modifier mon profil',
              subtitle: 'Photo, identité, ville et informations',
              onTap: () async {
                final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AmlEditProfileScreen(initialProfile: profile)));
                if (changed == true && mounted) await _load();
              },
            ),
            if (profile?['profile_type']?.toString() == 'fighter')
              _ProfileTile(
                icon: Icons.badge_outlined,
                title: 'Ma carte AML',
                subtitle: 'Carte professionnelle et QR code',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlProfileSettingsScreen(showFighterCard: true))),
              ),
            if (profile?['profile_type']?.toString() == 'fighter')
              _ProfileTile(
                icon: Icons.bar_chart_outlined,
                title: 'Mes statistiques',
                subtitle: 'Palmarès et performances',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMyBadgesScreen())),
              ),
            const SizedBox(height: 8),
            _SectionTitle(title: 'MON AML'),
            _ProfileTile(icon: Icons.account_balance_wallet_outlined, title: 'Solde AML', subtitle: 'XP gagnés et crédits pour les billets', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlWalletScreen()))),
            _ProfileTile(icon: Icons.emoji_events_outlined, title: 'Badges & XP', subtitle: 'Tes badges, tes points et le classement', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMyBadgesScreen()))),
            _ProfileTile(icon: Icons.confirmation_number_outlined, title: 'Mes billets', subtitle: 'Événements et accès', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMyTicketsScreen()))),
            _ProfileTile(icon: Icons.shopping_bag_outlined, title: 'Mes commandes', subtitle: 'Suivre mes achats AML', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlOrdersScreen()))),
            _ProfileTile(icon: Icons.settings_outlined, title: 'Paramètres', subtitle: 'Sécurité du compte et mise à jour AML', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlProfileSettingsScreen()))),
            _ProfileTile(icon: Icons.system_update_alt, title: 'Mise à jour AML', subtitle: 'Vérifier, télécharger et installer la dernière version', onTap: () => AppUpdateService.checkAndInstall(context)),
            const SizedBox(height: 8),
            if (SupabaseService.client?.auth.currentUser?.email?.trim().toLowerCase() == 'idrissjeux1987@gmail.com')
              _ProfileTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'AML Admin',
                subtitle: 'Centre de contrôle AML',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAdminScreen())),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('SE DÉCONNECTER', style: TextStyle(fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white12), minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }

  String _profileType(String? value) {
    return {
      'fan': 'Fan',
      'fighter': 'Combattant',
      'coach': 'Coach',
      'referee': 'Arbitre',
      'media': 'Média',
      'organization': 'Organisation',
      'other': 'Autre',
    }[value] ?? 'Membre AML';
  }

  void _comingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title arrive dans la prochaine étape.')));
  }
}

class _GuestProfile extends StatelessWidget {
  final VoidCallback onAuth;
  const _GuestProfile({required this.onAuth});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pBlack,
    appBar: AppBar(title: const Text('Mon espace', style: TextStyle(fontWeight: FontWeight.w900))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const _DefaultAvatar(size: 96),
          const SizedBox(height: 18),
          const Text('Ton espace AML', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Connecte-toi ou crée ton compte pour accéder à Community, tes messages, notifications, commandes et ton profil.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.4)),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: onAuth, style: ElevatedButton.styleFrom(backgroundColor: _pBlue), child: const Text('SE CONNECTER / CRÉER UN COMPTE', style: TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  final String? avatar, username, city;
  final String name, type;
  final int unread;
  const _ProfileHeader({required this.avatar, required this.username, required this.name, required this.type, required this.city, required this.unread});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF003B55), Color(0xFF001B27)]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _pBlue.withOpacity(.22)),
    ),
    child: Row(children: [
      Stack(children: [
        _Avatar(url: avatar, size: 76),
        if (unread > 0) Positioned(right: 0, top: 0, child: _CountBadge(count: unread)),
      ]),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text('@${username ?? 'membreaml'}', style: const TextStyle(color: _pBlue, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('$type${city == null || city!.isEmpty ? '' : ' • ${city!}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ])),
    ]),
  );
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _BadgeIcon({required this.icon, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(onPressed: onTap, icon: Stack(clipBehavior: Clip.none, children: [Icon(icon, color: Colors.white), if (count > 0) Positioned(right: -5, top: -7, child: _CountBadge(count: count))]));
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
    child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
  );
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  const _Avatar({this.url, required this.size});
  @override
  Widget build(BuildContext context) => AmlFaceAvatar(radius: size / 2, backgroundColor: const Color(0xFF17232A), image: url != null && url!.isNotEmpty ? CachedNetworkImageProvider(url!) : null, child: url == null || url!.isEmpty ? Icon(Icons.person, size: size * .45, color: Colors.white38) : null);
}

class _DefaultAvatar extends StatelessWidget {
  final double size;
  const _DefaultAvatar({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(color: Color(0xFF17232A), shape: BoxShape.circle),
    child: Icon(Icons.person, size: 44, color: Colors.white38),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 9),
    child: Text(title, style: const TextStyle(color: _pBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
  );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final VoidCallback? onTap;
  const _ProfileTile({required this.icon, required this.title, required this.subtitle, this.badge, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: _pSurface, borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      onTap: onTap,
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: _pBlue.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _pBlue)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: badge != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [_CountBadge(count: int.tryParse(badge!) ?? 0), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Colors.white38)])
          : const Icon(Icons.chevron_right, color: Colors.white38),
    ),
  );
}
