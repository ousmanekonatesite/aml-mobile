import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/fights/fights_screen.dart';
import 'screens/fighters/fighters_screen.dart';
import 'screens/tv/aml_tv_screen.dart';
import 'services/supabase_service.dart';
import 'services/shop_repository.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/shop/checkout_screen.dart';
import 'screens/shop/orders_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/admin/ticket_control_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/content/aml_content_screen.dart';
import 'screens/predictions/predictions_screen.dart';
import 'services/profile_repository.dart';
import 'services/ticket_repository.dart';
import 'services/home_repository.dart';
import 'services/fights_repository.dart';
import 'services/aml_content_repository.dart';
import 'services/fighter_repository.dart';
import 'services/app_update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets_public_media.dart';

const Color amlBlue = Color(0xFF00AEEF);
const Color amlBlack = Color(0xFF050505);
const Color amlSurface = Color(0xFF111111);
const Color amlSurface2 = Color(0xFF171717);
const Color amlGold = Color(0xFFFFB800);
const Color amlMuted = Color(0xFF9B9B9B);
const String amlAdminEmail = 'idrissjeux1987@gmail.com';

bool isAmlAdminUser() =>
    SupabaseService.client?.auth.currentUser?.email?.trim().toLowerCase() ==
    amlAdminEmail;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmlArenaApp());
}

class AmlArenaApp extends StatelessWidget {
  const AmlArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AML Arena',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: amlBlack,
        colorScheme: ColorScheme.fromSeed(
          seedColor: amlBlue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: amlBlack,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AmlStartupGate(),
    );
  }
}

class AmlHomePage extends StatefulWidget {
  const AmlHomePage({super.key});

  @override
  State<AmlHomePage> createState() => _AmlHomePageState();
}

class _AmlHomePageState extends State<AmlHomePage> {
  int selectedIndex = 0;
  String? selectedEventId;

  void openTab(int index) => setState(() { selectedIndex = index; if (index == 1) selectedEventId = null; });
  void openEventFights(String eventId) => setState(() { selectedEventId = eventId; selectedIndex = 1; });

  void openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AmlProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amlBlack,
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            HomeContent(onOpenTab: openTab, onOpenEventFights: openEventFights),
            FightsScreen(key: ValueKey(selectedEventId ?? 'all-fights'), eventId: selectedEventId),
            const FightersScreen(),
            const AmlTvScreen(),
            const AmlShopScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0D0D0D),
        indicatorColor: amlBlue.withOpacity(0.18),
        selectedIndex: selectedIndex,
        onDestinationSelected: openTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_mma_outlined),
            selectedIcon: Icon(Icons.sports_mma),
            label: 'Combats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Fighters',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle_fill),
            label: 'AML TV',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Boutique',
          ),
        ],
      ),
    );
  }
}

class AmlStartupGate extends StatefulWidget {
  const AmlStartupGate({super.key});
  @override
  State<AmlStartupGate> createState() => _AmlStartupGateState();
}

class _AmlStartupGateState extends State<AmlStartupGate> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _prepareApp();
  }

  Future<void> _prepareApp() async {
    // Keep the branded splash visible while Supabase initializes and the first
    // frame is prepared. Do not block forever if remote initialization fails.
    await Future.wait<void>([
      SupabaseService.initialize().catchError((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 1100)),
    ]);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        return const AmlHomePage();
      }
      return const _AmlSplashScreen();
    },
  );
}

class _AmlSplashScreen extends StatelessWidget {
  const _AmlSplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: amlBlack,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmlLogo(width: 230),
          SizedBox(height: 34),
          SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: amlBlue)),
          SizedBox(height: 18),
          Text('Préparation de votre expérience AML…', style: TextStyle(color: amlMuted, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class AmlLogo extends StatelessWidget {
  final double width;
  final bool compact;

  const AmlLogo({super.key, this.width = 88, this.compact = false});

  static const logoUrl =
      'https://aml-ci.com/wp-content/uploads/2023/01/AML1XBETWHITE.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: compact ? 38 : 52,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Text(
          'AML',
          style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class AmlHomeHeader extends StatefulWidget {
  final VoidCallback onProfile;
  final VoidCallback onCommunity;
  final ValueChanged<int> onOpenTab;

  const AmlHomeHeader({
    super.key,
    required this.onProfile,
    required this.onCommunity,
    required this.onOpenTab,
  });

  @override
  State<AmlHomeHeader> createState() => _AmlHomeHeaderState();
}

class _AmlHomeHeaderState extends State<AmlHomeHeader> {
  final repo = ProfileRepository();
  Map<String, dynamic>? profile;
  int unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.client?.auth.currentUser == null) return;
    final results = await Future.wait([repo.loadMine(), repo.unreadNotifications()]);
    if (!mounted) return;
    setState(() {
      profile = results[0] as Map<String, dynamic>?;
      unread = results[1] as int;
    });
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AmlFightMenu(
        onOpenTab: widget.onOpenTab,
        onProfile: widget.onProfile,
        onCommunity: widget.onCommunity,
        onUpdate: () => AppUpdateService.checkAndInstall(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = profile?['avatar_url']?.toString();
    return Row(
      children: [
        Container(
          width: 108,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: AmlLogo(compact: true, width: 82)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AFRICAN MMA LEAGUE', style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              SizedBox(height: 5),
              Row(children: [
                Text('Sponsored by ', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w600)),
                Text('1XBET', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: .3)),
              ]),
            ],
          ),
        ),
        _HeaderIcon(
          icon: Icons.menu_rounded,
          onTap: _openMenu,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onProfile,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: amlSurface2,
                backgroundImage: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null || avatar.isEmpty ? const Icon(Icons.person_outline, color: Colors.white70) : null,
              ),
              if (unread > 0)
                Positioned(
                  right: -5,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: amlSurface2, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

class _AmlFightMenu extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  final VoidCallback onProfile;
  final VoidCallback onCommunity;
  final VoidCallback onUpdate;

  const _AmlFightMenu({
    required this.onOpenTab,
    required this.onProfile,
    required this.onCommunity,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: amlBlue.withOpacity(.32)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: AmlLogo(compact: true, width: 40)),
              ),
              const SizedBox(width: 11),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AML FIGHT MENU', style: TextStyle(color: amlBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                SizedBox(height: 2),
                Text('Ton univers MMA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
            ]),
            const SizedBox(height: 10),
            _MenuGroup(title: 'AML ARENA', items: [
              _MenuItem(icon: Icons.sports_mma, label: 'Combats', onTap: () { Navigator.pop(context); onOpenTab(1); }),
              _MenuItem(icon: Icons.people_outline, label: 'Fighters', onTap: () { Navigator.pop(context); onOpenTab(2); }),
              _MenuItem(icon: Icons.play_circle_outline, label: 'AML TV', onTap: () { Navigator.pop(context); onOpenTab(3); }),
              _MenuItem(icon: Icons.newspaper_outlined, label: 'AML Infos', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlContentScreen())); }),
              _MenuItem(icon: Icons.emoji_events_outlined, label: 'Pronos', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlPredictionsScreen())); }),
              _MenuItem(icon: Icons.confirmation_num_outlined, label: 'Tickets', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlTicketsScreen())); }),
              _MenuItem(icon: Icons.shopping_bag_outlined, label: 'Boutique', onTap: () { Navigator.pop(context); onOpenTab(4); }),
            ]),
            const SizedBox(height: 8),
            _MenuGroup(title: 'AML COMMUNITY', items: [
              _MenuItem(icon: Icons.forum_outlined, label: 'Community', onTap: () { Navigator.pop(context); onCommunity(); }),
              _MenuItem(icon: Icons.emoji_events_outlined, label: 'Classements', onTap: () { Navigator.pop(context); onOpenTab(1); }),
              _MenuItem(icon: Icons.notifications_none, label: 'Notifications', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlNotificationsScreen())); }),
            ]),
            const SizedBox(height: 8),
            _MenuGroup(title: 'MON ESPACE', items: [
              _MenuItem(icon: Icons.person_outline, label: 'Mon profil', onTap: () { Navigator.pop(context); onProfile(); }),
              _MenuItem(icon: Icons.chat_bubble_outline, label: 'Messages', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMessagesScreen())); }),
              _MenuItem(icon: Icons.settings_outlined, label: 'Paramètres', onTap: () { Navigator.pop(context); onProfile(); }),
              _MenuItem(icon: Icons.system_update_alt_rounded, label: 'Mise à jour', onTap: () { Navigator.pop(context); onUpdate(); }),
              if (isAmlAdminUser())
                _MenuItem(icon: Icons.admin_panel_settings_outlined, label: 'Espace Admin', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAdminScreen())); }),
              if (SupabaseService.client?.auth.currentUser != null)
                _MenuItem(icon: Icons.qr_code_scanner, label: 'Scanner billets (superviseur)', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlTicketControlScreen())); }),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 3, bottom: 7), child: Text(title, style: const TextStyle(color: amlBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
    Wrap(spacing: 8, runSpacing: 8, children: items),
  ]);
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(color: amlSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

class HomeContent extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  final ValueChanged<String> onOpenEventFights;
  const HomeContent({super.key, required this.onOpenTab, required this.onOpenEventFights});
  @override State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final AmlHomeRepository repo = AmlHomeRepository();
  Map<String, dynamic> settings = const {};
  List<Map<String, dynamic>> sections = const [];
  bool loading = true;

  final Map<String, Map<String, dynamic>> defaults = const {
    'featured_event': {'title':'ÉVÉNEMENT VEDETTE','action_label':'Voir les combats','sort_order':10},
    'next_fight': {'title':'PROCHAIN COMBAT','action_label':'Tous les combats','sort_order':20},
    'results': {'title':'DERNIERS RÉSULTATS','action_label':'Voir tout','sort_order':30},
    'rankings': {'title':'CLASSEMENTS AML','action_label':'Classements','sort_order':40},
    'fighters': {'title':'FIGHTERS VEDETTES','action_label':'Voir les fighters','sort_order':50},
    'tv': {'title':'AML TV','action_label':'Tout voir','sort_order':60},
    'tickets': {'title':'TICKETS','action_label':'','sort_order':70},
    'shop': {'title':'AML SHOP','action_label':'Boutique','sort_order':80},
  };

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final result = await Future.wait([repo.homeSettings(), repo.homeSections()]);
    if (!mounted) return;
    final raw = List<Map<String,dynamic>>.from(result[1] as List);
    setState(() { settings = Map<String,dynamic>.from(result[0] as Map); sections = raw.isEmpty ? defaults.entries.map((e)=>{'section_key':e.key,...e.value,'is_visible':true}).toList() : raw; loading=false; });
  }

  Map<String,dynamic> cfg(String key) => sections.cast<Map<String,dynamic>>().firstWhere((e)=>e['section_key']==key, orElse:()=>{'section_key':key,...(defaults[key] ?? const {})});

  List<Widget> _section(String key) {
    final c=cfg(key); final title=(c['title'] ?? defaults[key]?['title'] ?? key).toString(); final action=(c['action_label'] ?? defaults[key]?['action_label'] ?? '').toString();
    final description=(c['description']??'').toString(); final image=(c['image_url']??'').toString().trim(); final header=SliverPadding(padding:const EdgeInsets.fromLTRB(20,28,20,13),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SectionHeader(title:title,action:action,description:description),if(image.isNotEmpty) const SizedBox(height:10),if(image.isNotEmpty) AmlPublicMedia(url:image,height:120,borderRadius:BorderRadius.circular(16))])));
    switch(key){
      case 'featured_event': return [header,SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,0),sliver:SliverToBoxAdapter(child:_FeaturedEventCard(onOpenTab:widget.onOpenTab, onOpenEventFights:widget.onOpenEventFights)))];
      case 'next_fight': final content = c['content'] is Map ? Map<String,dynamic>.from(c['content']) : <String,dynamic>{}; return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:_MainFightCard(content:content,onOpenTab:widget.onOpenTab)))];
      case 'results': return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:_ResultsPanel(onOpenTab:widget.onOpenTab)))];
      case 'rankings': return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:const _RankingPanel()))];
      case 'fighters': return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:_FeaturedFighters(onOpenTab:widget.onOpenTab)))];
      case 'tv': return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:_TvPanel(onOpenTab:widget.onOpenTab)))];
      case 'tickets': return [header,SliverPadding(padding:const EdgeInsets.symmetric(horizontal:20),sliver:SliverToBoxAdapter(child:_TicketsPanel(onTap:()=>_open(context,const AmlTicketsScreen()))))];
      case 'shop': return [header,SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,35),sliver:SliverToBoxAdapter(child:_ShopPanel(onTap:()=>widget.onOpenTab(4))))];
      default: return const [];
    }
  }

  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child:CircularProgressIndicator(color:amlBlue));
    final ordered = [...sections]..sort((a,b)=>(a['sort_order'] as num? ?? 100).compareTo(b['sort_order'] as num? ?? 100));
    final visible = ordered.where((e)=>e['is_visible']!=false && defaults.containsKey(e['section_key'])).map((e)=>e['section_key'].toString()).toList();
    final heroEnabled = settings['hero_enabled'] != false;
    return RefreshIndicator(color:amlBlue,onRefresh:_load,child:CustomScrollView(physics:const BouncingScrollPhysics(),slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(16,12,16,0),sliver:SliverToBoxAdapter(child:AmlHomeHeader(onProfile:()=>_open(context,const AmlProfileScreen()),onCommunity:()=>_open(context,const AmlCommunityScreen()),onOpenTab:widget.onOpenTab))),
      if(heroEnabled) SliverPadding(padding:const EdgeInsets.fromLTRB(20,18,20,0),sliver:SliverToBoxAdapter(child:_ManagedHomeHero(settings:settings))),
      ...visible.expand(_section),
    ]));
  }
}

class _ManagedHomeHero extends StatelessWidget {
  final Map<String,dynamic> settings;
  const _ManagedHomeHero({required this.settings});
  @override Widget build(BuildContext context){
    final image=settings['hero_image_url']?.toString()??''; final title=settings['hero_title']?.toString()??'African MMA League'; final subtitle=settings['hero_subtitle']?.toString()??'Toute l’actualité AML, les combats et la communauté.';
    return Container(height:170,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.white10)),child:Stack(children:[
      if(image.isNotEmpty) Positioned.fill(child:CachedNetworkImage(imageUrl:image,fit:BoxFit.cover,errorWidget:(_,__,___)=>const SizedBox.shrink())),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Colors.black.withOpacity(.08),Colors.black.withOpacity(.88)])))),
      Positioned(left:18,right:18,bottom:18,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:10))]))
    ]));
  }
}

class _FeaturedEventCard extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  final ValueChanged<String> onOpenEventFights;
  const _FeaturedEventCard({required this.onOpenTab, required this.onOpenEventFights});
  @override State<_FeaturedEventCard> createState() => _FeaturedEventCardState();
}

class _FeaturedEventCardState extends State<_FeaturedEventCard> {
  final repo = TicketRepository();
  Map<String,dynamic>? event;
  bool loading = true;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async { try { final events=await repo.upcomingEvents(); if(!mounted)return; setState(()=>event=events.isEmpty?null:events.first); } finally { if(mounted)setState(()=>loading=false); } }
  @override Widget build(BuildContext context){
    if(loading) return _HomeLoadingCard(height:260);
    final e=event;
    if(e==null) return _HomeEmptyCard(icon:Icons.event_busy,title:'Aucun événement officiel à venir.',subtitle:'Les prochaines informations AML apparaîtront ici.');
    final image=(e['cover_url']??e['poster_url'])?.toString()??'';
    final date=_formatHomeDate(e['starts_at']);
    return Container(height:260,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(26),border:Border.all(color:Colors.white10)),child:Stack(children:[
      if(image.isNotEmpty) Positioned.fill(child:CachedNetworkImage(imageUrl:image,fit:BoxFit.cover,errorWidget:(_,__,___)=>const SizedBox.shrink())),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withOpacity(.12),Colors.black.withOpacity(.92)])))),
      Positioned(left:17,top:16,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:amlBlue,borderRadius:BorderRadius.circular(8)),child:const Text('PROCHAIN ÉVÉNEMENT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)))),
      Positioned(left:18,right:18,bottom:58,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e['name']?.toString()??'Événement AML',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text([if(date.isNotEmpty)date,if((e['city']??'').toString().isNotEmpty)e['city'].toString(),if((e['venue_name']??'').toString().isNotEmpty)e['venue_name'].toString()].join(' • '),style:const TextStyle(color:Colors.white70,fontSize:10))])),
      Positioned(left:18,bottom:16,child:GestureDetector(onTap:()=>widget.onOpenEventFights(e['id'].toString()),child:Container(padding:const EdgeInsets.symmetric(horizontal:15,vertical:10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:const Text('VOIR LES COMBATS',style:TextStyle(color:amlBlue,fontSize:10,fontWeight:FontWeight.w900))))),
    ]));
  }
}

class _MainFightCard extends StatefulWidget { final ValueChanged<int> onOpenTab; final Map<String,dynamic> content; const _MainFightCard({required this.onOpenTab, this.content = const <String,dynamic>{}}); @override State<_MainFightCard> createState()=>_MainFightCardState(); }
class _MainFightCardState extends State<_MainFightCard>{
  final repo=FightsRepository(); List<Map<String,dynamic>> fights=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  // Réglages admin (section « next_fight ») : mode auto | event | competition, et nombre de combats.
  Future<void> _load() async{
    try{
      final cfg=widget.content;
      final mode=(cfg['mode']??(cfg['event_id']!=null?'event':'auto')).toString();
      var limit=int.tryParse('${cfg['limit']??1}')??1; if(limit<1)limit=1; if(limit>5)limit=5;
      final eventId=cfg['event_id']?.toString(); final competitionId=cfg['competition_id']?.toString();
      List<Map<String,dynamic>> x;
      if(mode=='event'&&eventId!=null&&eventId.isNotEmpty){x=await repo.upcoming(eventId:eventId);}
      else if(mode=='competition'&&competitionId!=null&&competitionId.isNotEmpty){x=await repo.upcoming(competitionId:competitionId);}
      else{x=await repo.upcoming();}
      final upcoming=x.where((f)=>['scheduled','live'].contains((f['status']??'').toString())).toList();
      final limitDate=DateTime.now().subtract(const Duration(hours:12));
      DateTime? dateOf(Map<String,dynamic> f)=>DateTime.tryParse('${(f['events'] is Map)?f['events']['starts_at']??'':''}');
      bool amlOf(Map<String,dynamic> f)=>(f['competition'] is Map)&&f['competition']['is_aml']==true;
      int rank(Map<String,dynamic> f){final d=dateOf(f);return (d!=null&&d.isBefore(limitDate))?2:(d==null?1:0);}
      upcoming.sort((a,b){
        final live=((b['status']=='live')?1:0)-((a['status']=='live')?1:0); if(live!=0)return live;
        if(mode=='auto'){final aml=(amlOf(b)?1:0)-(amlOf(a)?1:0); if(aml!=0)return aml;}
        final r=rank(a).compareTo(rank(b)); if(r!=0)return r;
        final da=dateOf(a),db=dateOf(b); if(da!=null&&db!=null){final c=da.compareTo(db); if(c!=0)return c;}
        final t=((b['title_bout']==true)?1:0)-((a['title_bout']==true)?1:0); if(t!=0)return t;
        return ((a['bout_order'] as num?)?.toInt()??999).compareTo((b['bout_order'] as num?)?.toInt()??999);
      });
      if(mounted)setState(()=>fights=upcoming.take(limit).toList());
    }finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context){if(loading)return _HomeLoadingCard(height:145); if(fights.isEmpty)return _HomeEmptyCard(icon:Icons.sports_mma,title:'Aucun combat officiel à venir.',subtitle:'La prochaine fight card apparaîtra ici.'); return Column(children:[for(final f in fights)Padding(padding:const EdgeInsets.only(bottom:10),child:_card(f))]);}
  Widget _card(Map<String,dynamic> f){ return GestureDetector(onTap:()=>widget.onOpenTab(1),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(21),border:Border.all(color:Colors.white10)),child:Column(children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:amlBlue.withOpacity(.13),borderRadius:BorderRadius.circular(7)),child:Text((f['title_bout']==true?'TITLE BOUT':'PROCHAIN COMBAT'),style:const TextStyle(color:amlBlue,fontSize:9,fontWeight:FontWeight.w900))),const Spacer(),Text((f['events']?['name']??'').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white38,fontSize:8,fontWeight:FontWeight.w800))]),const SizedBox(height:15),Row(children:[Expanded(child:_HomeFighter(f['fighter_a'])),Container(width:44,height:44,decoration:BoxDecoration(color:amlBlue,shape:BoxShape.circle),child:const Center(child:Text('VS',style:TextStyle(fontWeight:FontWeight.w900,fontSize:12)))),Expanded(child:_HomeFighter(f['fighter_b'],right:true))]),const SizedBox(height:12),Text([if((f['weight_category']?['name']??'').toString().isNotEmpty)(f['weight_category']['name']).toString(),if(f['scheduled_rounds']!=null)'${f['scheduled_rounds']} rounds'].join(' • '),style:const TextStyle(color:Colors.white54,fontSize:10,fontWeight:FontWeight.w700))])));}
}

class _HomeFighter extends StatelessWidget { final dynamic fighter; final bool right; const _HomeFighter(this.fighter,{this.right=false}); @override Widget build(BuildContext context){final m=fighter is Map?Map<String,dynamic>.from(fighter):<String,dynamic>{}; final first=(m['first_name']??'').toString();final last=(m['last_name']??'').toString();final name=(m['name']??'$first $last').toString().trim();final photo=(m['photo_url']??'').toString();return Column(crossAxisAlignment:right?CrossAxisAlignment.end:CrossAxisAlignment.start,children:[CircleAvatar(radius:29,backgroundColor:amlSurface2,backgroundImage:photo.isNotEmpty?CachedNetworkImageProvider(photo):null,child:photo.isEmpty?const Icon(Icons.person_outline,color:Colors.white38):null),const SizedBox(height:7),Text(name.isEmpty?'Données officielles à venir':name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))]);}}

class _ResultsPanel extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  const _ResultsPanel({required this.onOpenTab});
  @override State<_ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends State<_ResultsPanel> {
  final repo = AmlHomeRepository();
  List<Map<String,dynamic>> rows = [];
  bool loading = true;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    try { final x=await repo.recentResults(); if(mounted)setState(()=>rows=x.take(4).toList()); }
    finally { if(mounted)setState(()=>loading=false); }
  }
  @override Widget build(BuildContext context) {
    if(loading) return _HomeLoadingCard(height:90);
    if(rows.isEmpty) return _HomeEmptyCard(icon:Icons.flag_outlined,title:'Aucun résultat officiel disponible.',subtitle:'Les résultats publiés par AML apparaîtront ici.');
    return GestureDetector(
      onTap:()=>widget.onOpenTab(1),
      child:Container(
        decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white10)),
        child:Column(children: rows.map((r){
          final a=_displayName(r['fighter_a']); final b=_displayName(r['fighter_b']); final w=_displayName(r['winner']);
          return ListTile(dense:true,leading:const Icon(Icons.sports_mma,color:amlBlue),title:Text('$a  vs  $b',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),subtitle:Text(w.isEmpty?'Résultat officiel':w,style:const TextStyle(color:Colors.white38,fontSize:9)),trailing:Text((r['result']??'').toString(),style:const TextStyle(color:amlGold,fontSize:9,fontWeight:FontWeight.w800)));
        }).toList()),
      ),
    );
  }
}

class _RankingPanel extends StatefulWidget { const _RankingPanel(); @override State<_RankingPanel> createState()=>_RankingPanelState(); }
class _RankingPanelState extends State<_RankingPanel>{
  final repo=AmlHomeRepository(); List<Map<String,dynamic>> rows=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{try{final x=await repo.rankings();if(mounted)setState(()=>rows=x);}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){
    if(loading)return _HomeLoadingCard(height:100);
    if(rows.isEmpty)return _HomeEmptyCard(icon:Icons.leaderboard_outlined,title:'Classements officiels à venir.',subtitle:'Aucun classement publié dans la base AML.');
    return Container(decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white10)),child:Column(children:[
      const Padding(padding:EdgeInsets.fromLTRB(14,13,14,10),child:Row(children:[Expanded(child:Text('CLASSEMENTS OFFICIELS',style:TextStyle(color:amlGold,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1))),Text('AML',style:TextStyle(color:Colors.white38,fontSize:9,fontWeight:FontWeight.w800))])),
      ...rows.asMap().entries.map((e){final r=e.value;final name=(r['fighter_name']??r['name']??'').toString();final rank=(r['rank']??e.key+1).toString();final division=(r['weight_category_name']??r['division']??r['category']??'').toString();return _RankingRow(rank:rank,name:name.isEmpty?'Données officielles à venir':name,division:division.isEmpty?'Catégorie officielle à venir':division);}),
    ]));
  }
}

class _RankingRow extends StatelessWidget {
  final String rank,name,division;
  const _RankingRow({required this.rank,required this.name,required this.division});
  @override Widget build(BuildContext context)=>ListTile(dense:true,leading:SizedBox(width:28,child:Text(rank,style:const TextStyle(color:amlGold,fontWeight:FontWeight.w900))),title:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),subtitle:Text(division,style:const TextStyle(color:Colors.white38,fontSize:9)));
}

class _FeaturedFighters extends StatefulWidget { final ValueChanged<int> onOpenTab; const _FeaturedFighters({required this.onOpenTab}); @override State<_FeaturedFighters> createState()=>_FeaturedFightersState(); }
class _FeaturedFightersState extends State<_FeaturedFighters>{
  final repo=FighterRepository(); List<Map<String,dynamic>> rows=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{try{final x=await repo.getFighters();if(mounted)setState(()=>rows=x.take(6).toList());}finally{if(mounted)setState(()=>loading=false);}}
  @override Widget build(BuildContext context){
    if(loading)return _HomeLoadingCard(height:172);
    if(rows.isEmpty)return _HomeEmptyCard(icon:Icons.people_outline,title:'Aucun fighter AML publié.',subtitle:'Les profils officiels apparaîtront ici.');
    return SizedBox(height:172,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(_,i){
      final f=rows[i]; final photo=(f['photo_url']??'').toString();
      return GestureDetector(onTap:()=>widget.onOpenTab(2),child:Container(width:148,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Container(width:double.infinity,decoration:BoxDecoration(color:amlSurface2,borderRadius:BorderRadius.circular(13)),child:photo.isNotEmpty?ClipRRect(borderRadius:BorderRadius.circular(13),child:CachedNetworkImage(imageUrl:photo,fit:BoxFit.cover,errorWidget:(_,__,___)=>const Icon(Icons.person,color:Colors.white30,size:48))):const Icon(Icons.person,color:Colors.white30,size:48))),
        const SizedBox(height:8),Text((f['name']??'Données officielles à venir').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text('${f['nickname']??''}${(f['category']??'').toString().isNotEmpty?' • ${f['category']}':''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:amlBlue,fontSize:8,fontWeight:FontWeight.w800))
      ])));
    }));
  }
}

class _TvPanel extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const _TvPanel({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AmlHomeRepository().publishedVideos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _HomeLoadingCard(height: 150);
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return GestureDetector(
            onTap: () => onOpenTab(3),
            child: const _HomeEmptyCard(
              icon: Icons.live_tv_outlined,
              title: 'AML TV — contenu officiel à venir.',
              subtitle: 'Aucune vidéo publiée actuellement.',
            ),
          );
        }
        final row = rows.first;
        final media = row['external_url']?.toString().trim() ?? '';
        final thumbnail = row['thumbnail_path']?.toString().trim() ?? '';
        return GestureDetector(
          onTap: () => onOpenTab(3),
          child: Container(
            decoration: BoxDecoration(
              color: amlSurface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (media.isNotEmpty)
                  AmlPublicMedia(
                    url: media,
                    height: 145,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                  )
                else if (thumbnail.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                    child: CachedNetworkImage(
                      imageUrl: thumbnail,
                      height: 145,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.play_circle_fill, color: amlBlue, size: 19),
                          SizedBox(width: 7),
                          Text('AML TV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        row['title']?.toString() ?? 'Contenu AML TV',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row['description']?.toString() ?? 'Contenu officiel AML',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketsPanel extends StatelessWidget {
  final VoidCallback onTap; const _TicketsPanel({required this.onTap});
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:TicketRepository().eventsWithOffers(),builder:(context,s){
    if(s.connectionState==ConnectionState.waiting)return _HomeLoadingCard(height:84);
    final events=s.data??[]; final sale=events.where((e)=>(e['ticket_offers'] as List?)?.isNotEmpty==true).toList();
    return GestureDetector(onTap:onTap,child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(20),border:Border.all(color:amlGold.withOpacity(.18))),child:Row(children:[Container(width:50,height:50,decoration:BoxDecoration(color:amlGold.withOpacity(.12),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.confirmation_number_outlined,color:amlGold,size:25)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(sale.isEmpty?'Billetterie officielle à venir':'${sale.length} événement(s) avec billets disponibles',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(sale.isEmpty?'Aucune offre de billet publiée.':'Accéder aux offres officielles',style:const TextStyle(color:Colors.white54,fontSize:10))])),const Icon(Icons.arrow_forward_ios,color:Colors.white38,size:15)])));
  });
}

class _ShopPanel extends StatelessWidget {
  final VoidCallback onTap; const _ShopPanel({required this.onTap});
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:ShopRepository().getProducts(),builder:(context,s){
    if(s.connectionState==ConnectionState.waiting)return _HomeLoadingCard(height:120);
    final products=s.data??[]; if(products.isEmpty)return GestureDetector(onTap:onTap,child:const _HomeEmptyCard(icon:Icons.shopping_bag_outlined,title:'AML Shop — catalogue à venir.',subtitle:'Aucun produit actif n’est publié.'));
    return GestureDetector(onTap:onTap,child:SizedBox(height:145,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:products.take(4).length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(_,i){
      final p=products[i]; final image=(p['image_url']??'').toString();
      return Container(width:150,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Container(width:double.infinity,decoration:BoxDecoration(color:amlSurface2,borderRadius:BorderRadius.circular(12)),child:image.isNotEmpty?ClipRRect(borderRadius:BorderRadius.circular(12),child:CachedNetworkImage(imageUrl:image,fit:BoxFit.cover,errorWidget:(_,__,___)=>const Icon(Icons.shopping_bag,color:Colors.white30,size:40))):const Icon(Icons.shopping_bag,color:Colors.white30,size:40))),const SizedBox(height:7),Text((p['name']??'Produit AML').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(_formatXof(p['price_xof']),style:const TextStyle(color:amlGold,fontSize:9,fontWeight:FontWeight.w800))]));
    })));
  });
}

class _HomeLoadingCard extends StatelessWidget { final double height; const _HomeLoadingCard({required this.height}); @override Widget build(BuildContext context)=>Container(height:height,alignment:Alignment.center,decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(20)),child:const CircularProgressIndicator(strokeWidth:2,color:amlBlue)); }
class _HomeEmptyCard extends StatelessWidget { final IconData icon; final String title; final String subtitle; const _HomeEmptyCard({required this.icon,required this.title,required this.subtitle}); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:amlSurface,borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white10)),child:Row(children:[Icon(icon,color:Colors.white30,size:28),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Colors.white38,fontSize:9))]))]));}

String _displayName(dynamic value){if(value is! Map)return '';final first=(value['first_name']??'').toString().trim();final last=(value['last_name']??'').toString().trim();return (value['name']??'$first $last').toString().trim();}
String _formatHomeDate(dynamic value){if(value==null)return '';final d=DateTime.tryParse(value.toString());if(d==null)return '';const months=['janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];return '${d.day} ${months[d.month-1]} ${d.year}';}
String _formatXof(dynamic value){if(value==null)return 'Prix officiel à venir';final n=num.tryParse(value.toString());if(n==null)return value.toString();return '${n.toStringAsFixed(0)} FCFA';}

class SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final String description;

  const SectionHeader({super.key, required this.title, required this.action, this.description = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.2))),
          if (action.isNotEmpty) Text(action, style: const TextStyle(color: amlBlue, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.35)),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String title;
  final String price;
  final IconData icon;

  const _ProductCard({required this.title, required this.price, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amlSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: Icon(icon, size: 58, color: amlBlue))),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(price, style: const TextStyle(color: amlGold, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

enum _ShopCategory { tous, gants, shorts, tshirts, hoodies, casquettes, sacs, training, accessoires }

class _ShopProduct {
  final String? id;
  final String name;
  final String category;
  final _ShopCategory categoryId;
  final int price;
  final IconData icon;
  final String description;
  final bool drop;
  final bool featured;
  final List<String> variants;
  final String? imageUrl;
  final int stock;

  const _ShopProduct({
    this.id,
    required this.name,
    required this.category,
    required this.categoryId,
    required this.price,
    required this.icon,
    required this.description,
    this.drop = false,
    this.featured = false,
    this.variants = const [],
    this.imageUrl,
    this.stock = 999,
  });

  factory _ShopProduct.fromSupabase(Map<String, dynamic> row) {
    final category = (row['category_name'] ?? 'Accessoires').toString();
    final lower = category.toLowerCase();
    final categoryId = _shopCategoryFromName(lower);
    final name = (row['name'] ?? 'Produit AML').toString();
    final variants = _variantsForCategory(lower);
    return _ShopProduct(
      id: row['id']?.toString(),
      name: name,
      category: category,
      categoryId: categoryId,
      price: ((row['price'] as num?) ?? 0).round(),
      icon: _shopIconForCategory(lower),
      description: (row['description'] ?? 'Produit officiel AML.').toString(),
      drop: row['is_drop'] == true,
      featured: false,
      variants: variants,
      imageUrl: row['image_url']?.toString(),
      stock: ((row['stock_quantity'] as num?) ?? 0).round(),
    );
  }
}

_ShopCategory _shopCategoryFromName(String value) {
  if (value.contains('gant')) return _ShopCategory.gants;
  if (value.contains('short')) return _ShopCategory.shorts;
  if (value.contains('t-shirt') || value.contains('shirt')) return _ShopCategory.tshirts;
  if (value.contains('hood')) return _ShopCategory.hoodies;
  if (value.contains('casquette') || value.contains('cap')) return _ShopCategory.casquettes;
  if (value.contains('sac') || value.contains('bag')) return _ShopCategory.sacs;
  if (value.contains('train')) return _ShopCategory.training;
  return _ShopCategory.accessoires;
}

IconData _shopIconForCategory(String value) {
  if (value.contains('gant')) return Icons.back_hand_outlined;
  if (value.contains('short') || value.contains('hood')) return Icons.checkroom_outlined;
  if (value.contains('t-shirt') || value.contains('shirt')) return Icons.dry_cleaning_outlined;
  if (value.contains('casquette') || value.contains('cap')) return Icons.face_retouching_natural_outlined;
  if (value.contains('sac') || value.contains('bag')) return Icons.backpack_outlined;
  if (value.contains('train')) return Icons.fitness_center_outlined;
  return Icons.sports_outlined;
}

List<String> _variantsForCategory(String value) {
  if (value.contains('short') || value.contains('hood') || value.contains('t-shirt') || value.contains('shirt')) {
    return ['S', 'M', 'L', 'XL', 'XXL'];
  }
  return const [];
}

const List<_ShopProduct> _amlShopProducts = [];

class AmlShopScreen extends StatefulWidget {
  const AmlShopScreen({super.key});

  @override
  State<AmlShopScreen> createState() => _AmlShopScreenState();
}

class _AmlShopScreenState extends State<AmlShopScreen> {
  _ShopCategory selectedCategory = _ShopCategory.tous;
  String query = '';
  final Map<String, int> cart = {};
  final Set<String> favorites = {};
  final ShopRepository _shopRepository = ShopRepository();
  List<_ShopProduct> products = List<_ShopProduct>.of(_amlShopProducts);
  bool _shopLoading = true;
  String? _shopError;

  int get cartCount => cart.values.fold(0, (sum, quantity) => sum + quantity);

  int get cartTotal => cart.entries.fold(0, (sum, entry) {
    final product = products.firstWhere((p) => p.name == entry.key);
    return sum + product.price * entry.value;
  });

  List<_ShopProduct> get filteredProducts {
    return products.where((product) {
      final categoryOk = selectedCategory == _ShopCategory.tous || product.categoryId == selectedCategory;
      final q = query.trim().toLowerCase();
      final searchOk = q.isEmpty || product.name.toLowerCase().contains(q) || product.category.toLowerCase().contains(q);
      return categoryOk && searchOk;
    }).toList();
  }

  void addToCart(_ShopProduct product) {
    final current = cart[product.name] ?? 0;
    if (product.stock <= 0 || current >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit indisponible ou stock maximum atteint.')),
      );
      return;
    }
    setState(() => cart[product.name] = current + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ajouté au panier'),
        backgroundColor: amlSurface2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  void openProduct(_ShopProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShopProductDetailScreen(
          product: product,
          initialQuantity: cart[product.name] ?? 0,
          onAdd: () => addToCart(product),
        ),
      ),
    );
  }

  Future<void> checkout() async {
    final items = cart.entries.map((entry) {
      final product = products.firstWhere((p) => p.name == entry.key);
      final quantity = entry.value;
      return {
        'product_id': product.id,
        'product_name': product.name,
        'quantity': quantity,
        'unit_price': product.price,
        'total_price': product.price * quantity,
        'variant': null,
      };
    }).toList();

    if (items.isEmpty) return;
    final orderId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => AmlCheckoutScreen(items: items, total: cartTotal)),
    );
    if (!mounted || orderId == null) return;
    setState(() => cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande #${orderId.substring(0, 8).toUpperCase()} enregistrée.'), backgroundColor: amlSurface2),
    );
  }

  void openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShopCartScreen(
          cart: cart,
          products: products,
          total: cartTotal,
          onCheckout: checkout,
          onQuantityChanged: (name, quantity) {
            setState(() {
              if (quantity <= 0) {
                cart.remove(name);
              } else {
                cart[name] = quantity;
              }
            });
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadShopProducts();
  }

  Future<void> _loadShopProducts() async {
    try {
      final live = await _shopRepository.getProducts();
      if (!mounted) return;
      setState(() {
        if (live.isNotEmpty) products = live.map(_ShopProduct.fromSupabase).toList();
        _shopLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shopLoading = false;
        _shopError = 'Catalogue AML temporairement indisponible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = <MapEntry<_ShopCategory, String>>[
      const MapEntry(_ShopCategory.tous, 'Tous'),
      const MapEntry(_ShopCategory.gants, 'Gants'),
      const MapEntry(_ShopCategory.shorts, 'Shorts'),
      const MapEntry(_ShopCategory.tshirts, 'T-Shirts'),
      const MapEntry(_ShopCategory.hoodies, 'Hoodies'),
      const MapEntry(_ShopCategory.casquettes, 'Casquettes'),
      const MapEntry(_ShopCategory.sacs, 'Sacs'),
      const MapEntry(_ShopCategory.training, 'Training'),
      const MapEntry(_ShopCategory.accessoires, 'Accessoires'),
    ];

    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(
        title: const Text('AML SHOP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(onPressed: openCart, icon: const Icon(Icons.shopping_bag_outlined)),
                if (cartCount > 0)
                  Positioned(
                    right: 1,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(10)),
                      child: Text('$cartCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF003B55), Color(0xFF001B27), Color(0xFF0D0D0D)],
                  ),
                  border: Border.all(color: amlBlue.withOpacity(0.28)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('AML OFFICIAL GEAR', style: TextStyle(color: amlGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                          SizedBox(height: 8),
                          Text('ÉQUIPE-TOI COMME UN FIGHTER.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.0)),
                          SizedBox(height: 9),
                          Text('Équipement, vêtements et accessoires officiels AML.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.sports_mma, size: 39, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_shopLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (_shopError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(_shopError!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: amlSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 55,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final entry = categories[index];
                  final selected = selectedCategory == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => setState(() => selectedCategory = entry.key),
                    selectedColor: amlBlue,
                    backgroundColor: amlSurface,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
                    side: BorderSide(color: selected ? amlBlue : Colors.white10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                },
              ),
            ),
          ),
          if (products.any((p) => p.drop))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: const [
                    Icon(Icons.local_fire_department, color: amlBlue, size: 19),
                    SizedBox(width: 7),
                    Text('AML DROP', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Spacer(),
                    Text('ÉDITION LIMITÉE', style: TextStyle(color: amlGold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  final isFavorite = favorites.contains(product.name);
                  return _ShopGridCard(
                    product: product,
                    isFavorite: isFavorite,
                    onFavorite: () => setState(() {
                      if (isFavorite) {
                        favorites.remove(product.name);
                      } else {
                        favorites.add(product.name);
                      }
                    }),
                    onTap: () => openProduct(product),
                    onAdd: () => addToCart(product),
                  );
                },
                childCount: filteredProducts.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 11,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopGridCard extends StatelessWidget {
  final _ShopProduct product;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ShopGridCard({required this.product, required this.isFavorite, required this.onFavorite, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: amlSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.055)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [amlBlue.withOpacity(0.17), const Color(0xFF101010)],
                      ),
                    ),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: CachedNetworkImage(imageUrl: product.imageUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Icon(product.icon, size: 64, color: Colors.white.withOpacity(0.9)))),
                          )
                        : Center(child: Icon(product.icon, size: 64, color: Colors.white.withOpacity(0.9))),
                  ),
                  if (product.drop)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(8)),
                        child: const Text('DROP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: IconButton(
                      onPressed: onFavorite,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? amlBlue : Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.category.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, height: 1.15)),
                  if (product.stock < 10) ...[
                    const SizedBox(height: 4),
                    Text(product.stock <= 0 ? 'RUPTURE DE STOCK' : 'Plus que ${product.stock} en stock', style: TextStyle(color: product.stock <= 0 ? amlBlue : amlGold, fontSize: 8, fontWeight: FontWeight.w900)),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(child: Text(_formatXof(product.price), style: const TextStyle(color: amlGold, fontSize: 11, fontWeight: FontWeight.w900))),
                      GestureDetector(
                        onTap: product.stock <= 0 ? null : onAdd,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: product.stock <= 0 ? Colors.white12 : amlBlue, borderRadius: BorderRadius.circular(10)),
                          child: Icon(product.stock <= 0 ? Icons.block : Icons.add, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopProductDetailScreen extends StatefulWidget {
  final _ShopProduct product;
  final int initialQuantity;
  final VoidCallback onAdd;

  const _ShopProductDetailScreen({required this.product, required this.initialQuantity, required this.onAdd});

  @override
  State<_ShopProductDetailScreen> createState() => _ShopProductDetailScreenState();
}

class _ShopProductDetailScreenState extends State<_ShopProductDetailScreen> {
  int quantity = 1;
  String? selectedVariant;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) selectedVariant = widget.product.variants[1 < widget.product.variants.length ? 1 : 0];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(title: const Text('Détail produit', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF003B55), Color(0xFF111111)]),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Stack(
              children: [
                if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(imageUrl: p.imageUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Icon(p.icon, size: 120, color: Colors.white.withOpacity(0.92)))),
                  )
                else
                  Center(child: Icon(p.icon, size: 120, color: Colors.white.withOpacity(0.92))),
                if (p.drop)
                  Positioned(left: 16, top: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: amlBlue, borderRadius: BorderRadius.circular(9)), child: const Text('AML DROP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(p.category.toUpperCase(), style: const TextStyle(color: amlBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 7),
          Text(p.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.0)),
          const SizedBox(height: 10),
          Text(_formatXof(p.price), style: const TextStyle(color: amlGold, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Text(p.description, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.55)),
          if (p.variants.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('TAILLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              children: p.variants.map((variant) {
                final selected = selectedVariant == variant;
                return ChoiceChip(
                  label: Text(variant),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedVariant = variant),
                  selectedColor: amlBlue,
                  backgroundColor: amlSurface,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w800),
                  side: BorderSide(color: selected ? amlBlue : Colors.white12),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          const Text('QUANTITÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 9),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: () => setState(() => quantity = quantity > 1 ? quantity - 1 : 1)),
              SizedBox(width: 22, child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
              _QtyButton(icon: Icons.add, onTap: () => setState(() => quantity++)),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                for (var i = 0; i < quantity; i++) widget.onAdd();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: amlBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('AJOUTER AU PANIER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: amlSurface2, borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white10)),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ShopCartScreen extends StatelessWidget {
  final Map<String, int> cart;
  final List<_ShopProduct> products;
  final int total;
  final void Function(String name, int quantity) onQuantityChanged;
  final VoidCallback onCheckout;

  const _ShopCartScreen({required this.cart, required this.products, required this.total, required this.onCheckout, required this.onQuantityChanged});

  @override
  Widget build(BuildContext context) {
    final items = cart.entries.map((entry) {
      final product = products.firstWhere((p) => p.name == entry.key);
      return (product, entry.value);
    }).toList();

    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(title: const Text('Mon panier', style: TextStyle(fontWeight: FontWeight.w900))),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shopping_bag_outlined, size: 58, color: Colors.white24),
                    SizedBox(height: 15),
                    Text('Votre panier est vide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Ajoutez votre équipement AML préféré.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                ...items.map((item) {
                  final p = item.$1;
                  final quantity = item.$2;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: amlSurface, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        Container(width: 66, height: 66, decoration: BoxDecoration(color: amlBlue.withOpacity(0.13), borderRadius: BorderRadius.circular(14)), child: Icon(p.icon, color: Colors.white, size: 32)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(_formatXof(p.price), style: const TextStyle(color: amlGold, fontSize: 11, fontWeight: FontWeight.w800))])),
                        _QtyButton(icon: Icons.remove, onTap: () => onQuantityChanged(p.name, quantity - 1)),
                        SizedBox(width: 27, child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
                        _QtyButton(icon: Icons.add, onTap: () => onQuantityChanged(p.name, quantity + 1)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: amlSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: amlGold.withOpacity(0.12))),
                  child: Column(
                    children: [
                      Row(children: const [Expanded(child: Text('Sous-total', style: TextStyle(color: Colors.white60))), Text('Hors livraison', style: TextStyle(color: Colors.white38, fontSize: 10))]),
                      const SizedBox(height: 10),
                      Row(children: [const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),), Text(_formatXof(total), style: const TextStyle(color: amlGold, fontSize: 17, fontWeight: FontWeight.w900))]),
                      const SizedBox(height: 17),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: onCheckout,
                          style: ElevatedButton.styleFrom(backgroundColor: amlBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          child: const Text('PASSER LA COMMANDE', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class AmlTicketsScreen extends StatefulWidget {
  const AmlTicketsScreen({super.key});

  @override
  State<AmlTicketsScreen> createState() => _AmlTicketsScreenState();
}

class _AmlTicketsScreenState extends State<AmlTicketsScreen> {
  final TicketRepository repo = TicketRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.eventsWithOffers();
  }

  void reload() => setState(() => future = repo.eventsWithOffers());

  String _date(String? raw) {
    final dt = raw == null ? null : DateTime.tryParse(raw);
    if (dt == null) return 'Date officielle à venir';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _price(dynamic raw, dynamic currency) {
    final value = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (value == null) return 'Prix officiel à venir';
    final cur = (currency?.toString().trim().isNotEmpty == true) ? currency.toString() : 'XOF';
    return '${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => ' ')} $cur';
  }

  Future<void> _openPurchase(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _buyOffer(Map<String, dynamic> offer) async {
    final client = SupabaseService.client;
    if (client?.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour acheter un billet.')));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmer l’achat'),
      content: Text('Acheter « ${offer['name'] ?? 'Billet'} » pour ${offer['price_xof'] ?? '—'} crédits AML ?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Acheter'))],
    ));
    if (confirmed != true || !mounted) return;
    try {
      final result = await repo.buyTicket(offer['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Billet acheté. Code : ${result['ticket_code'] ?? 'voir Mes billets'}')));
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Achat impossible : ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(
        title: const Text('Tickets AML', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: amlBlue));
          }
          if (snapshot.hasError) {
            return const _TicketEmpty(
              icon: Icons.error_outline,
              title: 'Billetterie indisponible',
              subtitle: 'Les informations officielles n’ont pas pu être chargées.',
            );
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return RefreshIndicator(
              color: amlBlue,
              onRefresh: () async => reload(),
              child: ListView(children: const [
                SizedBox(height: 120),
                _TicketEmpty(
                  icon: Icons.confirmation_num_outlined,
                  title: 'Aucun événement en billetterie',
                  subtitle: 'Les événements et informations de vente seront affichés ici dès leur publication officielle.',
                ),
              ]),
            );
          }
          return RefreshIndicator(
            color: amlBlue,
            onRefresh: () async => reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              itemCount: events.length,
              itemBuilder: (_, index) {
                final event = events[index];
                final offers = List<Map<String, dynamic>>.from(event['ticket_offers'] ?? const []);
                final poster = event['poster_url']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: amlSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: amlBlue.withOpacity(.12)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (poster.isNotEmpty)
                      CachedNetworkImage(imageUrl: poster, height: 150, width: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('ÉVÉNEMENT OFFICIEL', style: TextStyle(color: amlBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(event['name']?.toString().trim().isNotEmpty == true ? event['name'].toString() : 'Événement officiel', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Row(children: [const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.white54), const SizedBox(width: 7), Text(_date(event['starts_at']?.toString()), style: const TextStyle(color: Colors.white70, fontSize: 12))]),
                        if ((event['venue_name']?.toString() ?? '').trim().isNotEmpty || (event['city']?.toString() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Row(children: [const Icon(Icons.location_on_outlined, size: 15, color: Colors.white54), const SizedBox(width: 7), Expanded(child: Text([event['venue_name'], event['city']].where((v) => v?.toString().trim().isNotEmpty == true).map((v) => v.toString()).join(' • '), style: const TextStyle(color: Colors.white70, fontSize: 12)))])
                        ],
                        const SizedBox(height: 16),
                        if (offers.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(color: amlBlue.withOpacity(.08), borderRadius: BorderRadius.circular(13)),
                            child: const Row(children: [Icon(Icons.info_outline, color: amlBlue, size: 18), SizedBox(width: 9), Expanded(child: Text('Billetterie officielle à venir.', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)))]),
                          )
                        else ...[
                          const Text('BILLETS DISPONIBLES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1)),
                          const SizedBox(height: 10),
                          ...offers.map((offer) => Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(.22), borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(offer['name']?.toString() ?? 'Billet', style: const TextStyle(fontWeight: FontWeight.w900)),
                                if ((offer['description']?.toString() ?? '').trim().isNotEmpty) ...[const SizedBox(height: 4), Text(offer['description'].toString(), style: const TextStyle(color: Colors.white54, fontSize: 11))],
                                const SizedBox(height: 7),
                                Text('${offer['price_xof'] ?? 'Prix à confirmer'} crédits AML', style: const TextStyle(color: amlGold, fontWeight: FontWeight.w900)),
                              ])),
                              if ((event['starts_at']?.toString() ?? '').trim().isEmpty)
                                const Text('Date de l’événement à définir', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w700))
                              else
                                ElevatedButton(onPressed: () => _buyOffer(offer), style: ElevatedButton.styleFrom(backgroundColor: amlBlue, foregroundColor: Colors.white), child: const Text('Acheter avec crédits AML')),
                            ]),
                          )),
                        ],
                      ]),
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TicketEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TicketEmpty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 54, color: amlBlue),
      const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, height: 1.45)),
    ]),
  );
}

