import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';
import '../../widgets_url_media_preview.dart';
import '../../services/supabase_service.dart';
import 'fighter_admin_screen.dart';
import 'external_fighters_admin_screen.dart';
import 'events_admin_screen.dart';
import 'aml_tv_admin_screen.dart';
import 'tickets_admin_screen.dart';
import 'xp_predictions_admin_screen.dart';
import 'users_admin_screen.dart';
import 'badges_admin_screen.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlAdminScreen extends StatefulWidget {
  const AmlAdminScreen({super.key});

  @override
  State<AmlAdminScreen> createState() => _AmlAdminScreenState();
}

class _AmlAdminScreenState extends State<AmlAdminScreen> {
  final AdminRepository repo = AdminRepository();
  Map<String, dynamic>? profile;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final authorized = await repo.isAuthorizedAdmin();
      if (!authorized) {
        if (!mounted) return;
        setState(() { loading = false; error = 'Accès administrateur refusé.'; });
        return;
      }
      final p = await repo.currentStaffProfile();
      if (!mounted) return;
      setState(() {
        profile = p;
        loading = false;
        if (p == null) error = 'Accès réservé au staff AML.';
        if (p?['is_suspended'] == true) error = 'Ce compte staff est suspendu.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Impossible de vérifier les droits staff.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(backgroundColor: _black, body: Center(child: CircularProgressIndicator(color: _blue)));
    }
    if (error != null) {
      return Scaffold(
        backgroundColor: _black,
        appBar: AppBar(title: const Text('AML Admin')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)))),
      );
    }
    final role = profile?['role']?.toString() ?? 'staff';
    return DefaultTabController(
      length: 12,
      child: Scaffold(
        backgroundColor: _black,
        appBar: AppBar(
          backgroundColor: _black,
          title: const Text('AML ADMIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          actions: [
            Padding(padding: const EdgeInsets.only(right: 14), child: Center(child: Text(role.toUpperCase(), style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11)))),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: _blue,
            tabs: [Tab(text: 'Dashboard'), Tab(text: 'Commandes'), Tab(text: 'Shop'), Tab(text: 'Tickets'), Tab(text: 'Fighters'), Tab(text: 'Fighters externes'), Tab(text: 'Événements'), Tab(text: 'XP & Pronos'), Tab(text: 'Badges'), Tab(text: 'Accueil'), Tab(text: 'Contenu'), Tab(text: 'Utilisateurs')],
          ),
        ),
        body: TabBarView(children: [
          _DashboardTab(repo: repo),
          _OrdersTab(repo: repo),
          _ShopAdminTab(repo: repo),
          const _TicketsAdminTab(),
          _FighterAdminTab(),
          const AmlExternalFightersAdminScreen(),
          const _EventsAdminTab(),
          const AmlXpPredictionsAdminScreen(),
          const AmlBadgesAdminScreen(),
          _HomeAdminTab(repo: repo),
          const AmlTvAdminScreen(),
          AmlUsersAdminScreen(repo: repo),
        ]),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final AdminRepository repo;
  const _DashboardTab({required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.recentOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        final pending = orders.where((o) => o['status'] == 'pending').length;
        final revenue = orders.fold<double>(0, (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0));
        return RefreshIndicator(
          color: _blue,
          onRefresh: () async { await repo.recentOrders(); },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(pending: pending, revenue: revenue),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: _MetricCard(icon: Icons.shopping_bag_outlined, label: 'Commandes', value: '${orders.length}')), const SizedBox(width: 10), Expanded(child: _MetricCard(icon: Icons.pending_actions_outlined, label: 'À traiter', value: '$pending'))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: _MetricCard(icon: Icons.people_outline, label: 'Utilisateurs', asyncValue: repo.count('profiles'))), const SizedBox(width: 10), Expanded(child: _MetricCard(icon: Icons.sports_mma_outlined, label: 'Fighters', asyncValue: repo.count('fighters')))]),
              const SizedBox(height: 18),
              const Text('CENTRE DE CONTRÔLE', style: TextStyle(color: _blue, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 12)),
              const SizedBox(height: 10),
              _AdminFeature(icon: Icons.person_search_outlined, title: 'Fighters', subtitle: 'Profils, stats, catégories et vérification'),
              _AdminFeature(icon: Icons.event_outlined, title: 'Événements & combats', subtitle: 'Cartes, résultats, rounds et statistiques'),
              _AdminFeature(icon: Icons.confirmation_number_outlined, title: 'Billetterie', subtitle: 'Offres, prix, stock et liens officiels'),
              _AdminFeature(icon: Icons.play_circle_outline, title: 'AML TV', subtitle: 'Catalogue vidéo, publication et liens Dropbox'),
              _AdminFeature(icon: Icons.campaign_outlined, title: 'Notifications & sponsors', subtitle: 'Communication et partenaires AML'),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int pending;
  final double revenue;
  const _HeroCard({required this.pending, required this.revenue});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF003B55), Color(0xFF001B27)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: _blue.withOpacity(.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('AML ARENA', style: TextStyle(color: _blue, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 8),
      const Text('Centre de contrôle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('$pending commande(s) à traiter • ${revenue.toStringAsFixed(0)} FCFA affichés', style: const TextStyle(color: Colors.white70)),
    ]),
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon; final String label; final String? value; final Future<int>? asyncValue;
  const _MetricCard({required this.icon, required this.label, this.value, this.asyncValue});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _blue), const SizedBox(height: 12), asyncValue == null ? Text(value ?? '0', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)) : FutureBuilder<int>(future: asyncValue, builder: (_, s) => Text('${s.data ?? '—'}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))]));
}

class _OrdersTab extends StatefulWidget {
  final AdminRepository repo;
  const _OrdersTab({required this.repo});
  @override State<_OrdersTab> createState() => _OrdersTabState();
}
class _OrdersTabState extends State<_OrdersTab> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = widget.repo.recentOrders(); }
  void reload() => setState(() => future = widget.repo.recentOrders());
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _blue));
    if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
    final orders = snapshot.data ?? [];
    if (orders.isEmpty) return const _ComingSoonTab(icon: Icons.receipt_long_outlined, title: 'Aucune commande', subtitle: 'Les commandes créées par les fans apparaîtront ici.');
    return RefreshIndicator(color: _blue, onRefresh: () async => reload(), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (_, i) {
      final o = orders[i];
      final status = o['status']?.toString() ?? 'pending';
      return Card(color: _surface, margin: const EdgeInsets.only(bottom: 10), child: ListTile(
        leading: CircleAvatar(backgroundColor: _blue.withOpacity(.12), child: const Icon(Icons.receipt_long, color: _blue)),
        title: Text('${o['shipping_name'] ?? 'Client AML'} • ${(o['total_amount'] as num?)?.toStringAsFixed(0) ?? '0'} FCFA', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${o['shipping_city'] ?? ''}\nStatut : ${_label(status)} • Paiement : ${o['payment_status'] ?? 'pending'}', style: const TextStyle(color: Colors.white54)),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(onSelected: (v) async {
          if (v.startsWith('pay:')) { await widget.repo.updateOrderPaymentStatus(o['id'].toString(), v.substring(4)); }
          else { await widget.repo.updateOrderStatus(o['id'].toString(), v); }
          reload();
        }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'pending', child: Text('Commande : en attente')),
          PopupMenuItem(value: 'processing', child: Text('Commande : en préparation')),
          PopupMenuItem(value: 'shipped', child: Text('Commande : expédiée')),
          PopupMenuItem(value: 'delivered', child: Text('Commande : livrée')),
          PopupMenuItem(value: 'cancelled', child: Text('Commande : annulée')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'pay:pending', child: Text('Paiement : en attente')),
          PopupMenuItem(value: 'pay:paid', child: Text('Paiement : payé')),
          PopupMenuItem(value: 'pay:failed', child: Text('Paiement : échoué')),
        ]),
      ));
    }));
  });
  String _label(String s) => {'pending':'En attente','processing':'En préparation','shipped':'Expédiée','delivered':'Livrée','cancelled':'Annulée'}[s] ?? s;
}

class _ShopAdminTab extends StatefulWidget {
  final AdminRepository repo;
  const _ShopAdminTab({required this.repo});

  @override
  State<_ShopAdminTab> createState() => _ShopAdminTabState();
}

class _ShopAdminTabState extends State<_ShopAdminTab> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        widget.repo.recentProducts(),
        widget.repo.productCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        products = List<Map<String, dynamic>>.from(result[0] as List);
        categories = List<Map<String, dynamic>>.from(result[1] as List);
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _product([Map<String, dynamic>? product]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProductDialog(product: product, categories: categories),
    );
    if (result == null) return;
    try {
      await widget.repo.saveProduct(result, product?['id']?.toString());
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’enregistrer : $e')),
        );
      }
    }
  }

  Future<void> _category([Map<String, dynamic>? category]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (result == null) return;
    try {
      await widget.repo.saveProductCategory(
        result,
        category?['id']?.toString(),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’enregistrer : $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    try {
      await widget.repo.deleteProduct(product['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : $e')),
        );
      }
    }
  }

  Future<void> _toggleProduct(Map<String, dynamic> product) async {
    await widget.repo.saveProduct(
      {'is_active': product['is_active'] != true},
      product['id'].toString(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    return RefreshIndicator(
      color: _blue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CATALOGUE AML SHOP',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _product(),
                icon: const Icon(Icons.add),
                label: const Text('Produit'),
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'Aucun produit. Crée le catalogue directement depuis l’admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ...products.map(
            (product) => Card(
              color: _surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _blue.withOpacity(.12),
                  child: const Icon(Icons.inventory_2_outlined, color: _blue),
                ),
                title: Text(
                  product['name']?.toString() ?? 'Produit',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${product['price'] ?? 0} ${product['currency'] ?? 'XOF'} • '
                  'Stock : ${product['stock_quantity'] ?? 0} • '
                  '${product['is_active'] == true ? 'Actif' : 'Masqué'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') await _product(product);
                    if (value == 'toggle') await _toggleProduct(product);
                    if (value == 'delete') await _deleteProduct(product);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text('Activer / masquer'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CATÉGORIES',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _category(),
                icon: const Icon(Icons.add_circle_outline, color: _blue),
              ),
            ],
          ),
          ...categories.map(
            (category) => Card(
              color: _surface,
              margin: const EdgeInsets.only(bottom: 7),
              child: ListTile(
                title: Text(category['name']?.toString() ?? ''),
                subtitle: Text(category['slug']?.toString() ?? ''),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: () => _category(category),
                      icon: const Icon(Icons.edit_outlined, color: _blue),
                    ),
                    IconButton(
                      onPressed: () async {
                        try {
                          await widget.repo.deleteProductCategory(
                            category['id'].toString(),
                          );
                          await _load();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Catégorie utilisée : $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget { final Map<String,dynamic>? product; final List<Map<String,dynamic>> categories; const _ProductDialog({this.product,required this.categories}); @override State<_ProductDialog> createState()=>_ProductDialogState(); }
class _ProductDialogState extends State<_ProductDialog>{
  late final TextEditingController name,slug,desc,price,stock,image;
  String? category; bool active=true,drop=false;
  @override void initState(){super.initState();final p=widget.product??{};name=TextEditingController(text:p['name']?.toString()??'');slug=TextEditingController(text:p['slug']?.toString()??'');desc=TextEditingController(text:p['description']?.toString()??'');price=TextEditingController(text:p['price']?.toString()??'0');stock=TextEditingController(text:p['stock_quantity']?.toString()??'0');image=TextEditingController(text:p['cover_image_path']?.toString()??'');category=p['category_id']?.toString();active=p['is_active']!=false;drop=p['is_drop']==true;}
  @override void dispose(){for(final c in[name,slug,desc,price,stock,image])c.dispose();super.dispose();}
  @override Widget build(BuildContext c)=>AlertDialog(backgroundColor:_surface,title:Text(widget.product==null?'Nouveau produit':'Modifier le produit'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nom')),TextField(controller:slug,decoration:const InputDecoration(labelText:'Slug')),TextField(controller:desc,decoration:const InputDecoration(labelText:'Description')),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Prix XOF')),TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stock')),TextField(controller:image,keyboardType:TextInputType.url,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'URL / chemin image')),if(image.text.trim().startsWith('http')) AmlUrlMediaPreview(url:image.text.trim(),compact:true),DropdownButtonFormField<String>(value:category,isExpanded:true,decoration:const InputDecoration(labelText:'Catégorie'),items:widget.categories.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString()))).toList(),onChanged:(v)=>setState(()=>category=v)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Produit actif'),value:active,onChanged:(v)=>setState(()=>active=v)),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Drop / édition limitée'),value:drop,onChanged:(v)=>setState(()=>drop=v))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annuler')),ElevatedButton(onPressed:(){if(name.text.trim().isEmpty||slug.text.trim().isEmpty)return;Navigator.pop(c,{'category_id':category,'name':name.text.trim(),'slug':slug.text.trim(),'description':desc.text.trim().isEmpty?null:desc.text.trim(),'price':double.tryParse(price.text.replaceAll(',','.'))??0,'currency':'XOF','stock_quantity':int.tryParse(stock.text)??0,'cover_image_path':image.text.trim().isEmpty?null:image.text.trim(),'is_active':active,'is_drop':drop});},child:const Text('Enregistrer'))]);
}

class _CategoryDialog extends StatefulWidget { final Map<String,dynamic>? category; const _CategoryDialog({this.category}); @override State<_CategoryDialog> createState()=>_CategoryDialogState(); }
class _CategoryDialogState extends State<_CategoryDialog>{late final TextEditingController name,slug;@override void initState(){super.initState();final c=widget.category??{};name=TextEditingController(text:c['name']?.toString()??'');slug=TextEditingController(text:c['slug']?.toString()??'');}@override void dispose(){name.dispose();slug.dispose();super.dispose();}@override Widget build(BuildContext c)=>AlertDialog(backgroundColor:_surface,title:Text(widget.category==null?'Nouvelle catégorie':'Modifier la catégorie'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nom')),TextField(controller:slug,decoration:const InputDecoration(labelText:'Slug'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annuler')),ElevatedButton(onPressed:(){if(name.text.trim().isEmpty||slug.text.trim().isEmpty)return;Navigator.pop(c,{'name':name.text.trim(),'slug':slug.text.trim()});},child:const Text('Enregistrer'))]);}

class _HomeAdminTab extends StatefulWidget {
  final AdminRepository repo;
  const _HomeAdminTab({required this.repo});

  @override
  State<_HomeAdminTab> createState() => _HomeAdminTabState();
}

class _HomeAdminTabState extends State<_HomeAdminTab> {
  Map<String, dynamic> settings = {};
  List<Map<String, dynamic>> sections = [];
  bool loading = true;
  late final TextEditingController heroTitle, heroSubtitle, heroImage;

  @override
  void initState() { super.initState(); heroTitle=TextEditingController(); heroSubtitle=TextEditingController(); heroImage=TextEditingController(); _load(); }
  @override
  void dispose() { heroTitle.dispose(); heroSubtitle.dispose(); heroImage.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final result = await Future.wait([widget.repo.homeSettings(), widget.repo.homeSectionsAdmin()]);
      if (!mounted) return;
      final a=Map<String,dynamic>.from(result[0] as Map);
      final b=List<Map<String,dynamic>>.from(result[1] as List);
      setState(() { settings=a; sections=b; heroTitle.text=a['hero_title']?.toString()??''; heroSubtitle.text=a['hero_subtitle']?.toString()??''; heroImage.text=a['hero_image_url']?.toString()??''; loading=false; });
    } catch(e) { if(mounted){setState(()=>loading=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Accueil : $e')));} }
  }

  Future<void> _save() async {
    try {
      settings['hero_title']=heroTitle.text.trim(); settings['hero_subtitle']=heroSubtitle.text.trim(); settings['hero_image_url']=heroImage.text.trim();
      await widget.repo.saveHomeSettings(settings);
      for(final section in sections){
        final id=section['id']?.toString(); if(id==null||id.isEmpty) continue;
        await widget.repo.saveHomeSection(id, {'title':section['title'],'action_label':section['action_label'],'description':section['description'],'image_url':section['image_url'],'content':section['content'] is Map?section['content']:<String,dynamic>{},'is_visible':section['is_visible']==true,'sort_order':(section['sort_order'] as num?)?.toInt()??100});
      }
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Accueil AML mis à jour.')));
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enregistrement impossible : $e')));}
  }

  Future<void> _addSection() async {
    final key=TextEditingController(), title=TextEditingController(), action=TextEditingController(), description=TextEditingController(), image=TextEditingController(), sort=TextEditingController(text:'100');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:_surface,title:const Text('Ajouter une information d’accueil'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:key,decoration:const InputDecoration(labelText:'Clé unique')),TextField(controller:title,decoration:const InputDecoration(labelText:'Titre')),TextField(controller:action,decoration:const InputDecoration(labelText:'Action / bouton')),TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Information métier')),TextField(controller:image,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'URL image')),TextField(controller:sort,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Ordre'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Ajouter'))]));
    if(ok==true){try{await widget.repo.createHomeSection({'section_key':key.text.trim(),'title':title.text.trim().isEmpty?key.text.trim():title.text.trim(),'action_label':action.text.trim().isEmpty?null:action.text.trim(),'description':description.text.trim().isEmpty?null:description.text.trim(),'image_url':image.text.trim().isEmpty?null:image.text.trim(),'content':<String,dynamic>{},'is_visible':true,'sort_order':int.tryParse(sort.text.trim())??100});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Ajout impossible : $e')));}}
    for(final c in [key,title,action,description,image,sort])c.dispose();
  }

  Future<void> _deleteSection(Map<String,dynamic> section) async {
    final id=section['id']?.toString(); if(id==null||id.isEmpty)return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:_surface,title:const Text('Supprimer cette section ?'),content:Text('« ${section['title']??section['section_key']} » sera retirée de l’accueil.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Supprimer'))]));
    if(ok==true){try{await widget.repo.deleteHomeSection(id);await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Suppression impossible : $e')));}}
  }

  // « Communauté AML » : compteurs RÉELS (membres inscrits, membres en ligne). Interrupteur, seuils et libellés.
  Future<void> _editCommunityStats(Map<String,dynamic> section) async {
    final raw=section['content'] is Map?Map<String,dynamic>.from(section['content'] as Map):<String,dynamic>{};
    bool flag(String k)=>raw[k]==null?true:(raw[k]==true||raw[k].toString()=='true');
    bool visible=section['is_visible']!=false, showMembers=flag('show_members'), showOnline=flag('show_online');
    final title=TextEditingController(text:section['title']?.toString()??'COMMUNAUTÉ AML');
    final minMembers=TextEditingController(text:'${raw['min_members']??0}'), minOnline=TextEditingController(text:'${raw['min_online']??0}');
    final membersLabel=TextEditingController(text:(raw['members_label']??'membres inscrits').toString()), onlineLabel=TextEditingController(text:(raw['online_label']??'en ligne maintenant').toString());
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      backgroundColor:_surface,
      title:const Text('Section « Communauté AML »'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Les chiffres affichés sont réels : membres inscrits et membres vus dans l’application ces 5 dernières minutes.',style:TextStyle(color:Colors.white60,fontSize:12,height:1.4)),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:visible,onChanged:(v)=>setD(()=>visible=v),title:const Text('Afficher la section sur l’accueil')),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titre affiché')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:showMembers,onChanged:(v)=>setD(()=>showMembers=v),title:const Text('Membres inscrits')),
        TextField(controller:membersLabel,decoration:const InputDecoration(labelText:'Libellé')),
        TextField(controller:minMembers,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Masquer sous (nombre minimum)')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:showOnline,onChanged:(v)=>setD(()=>showOnline=v),title:const Text('Membres en ligne')),
        TextField(controller:onlineLabel,decoration:const InputDecoration(labelText:'Libellé')),
        TextField(controller:minOnline,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Masquer sous (nombre minimum)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Enregistrer'))],
    )));
    if(ok==true){
      setState((){section['title']=title.text.trim();section['is_visible']=visible;section['content']=<String,dynamic>{'show_members':showMembers,'show_online':showOnline,'min_members':int.tryParse(minMembers.text.trim())??0,'min_online':int.tryParse(minOnline.text.trim())??0,'members_label':membersLabel.text.trim().isEmpty?'membres inscrits':membersLabel.text.trim(),'online_label':onlineLabel.text.trim().isEmpty?'en ligne maintenant':onlineLabel.text.trim()};});
      await _save();
    }
    title.dispose(); minMembers.dispose(); minOnline.dispose(); membersLabel.dispose(); onlineLabel.dispose();
  }

  // « Derniers résultats » : source (toutes / AML / une compétition) et nombre de résultats.
  Future<void> _editResults(Map<String,dynamic> section) async {
    final comps=<Map<String,dynamic>>[];
    try{comps.addAll(await widget.repo.adminCompetitions());}catch(_){}
    if(!mounted) return;
    final raw=section['content'] is Map?Map<String,dynamic>.from(section['content'] as Map):<String,dynamic>{};
    String source=(raw['source']??'all').toString(); if(!['all','aml','competition'].contains(source)) source='all';
    String? competitionId=raw['competition_id']?.toString(); if(competitionId!=null&&!comps.any((e)=>e['id'].toString()==competitionId)) competitionId=null;
    int limit=int.tryParse('${raw['limit']??4}')??4; if(limit<1)limit=1; if(limit>10)limit=10;
    final title=TextEditingController(text:section['title']?.toString()??'DERNIERS RÉSULTATS'), action=TextEditingController(text:section['action_label']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      backgroundColor:_surface,
      title:const Text('Section « Derniers résultats »'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titre affiché')),
        TextField(controller:action,decoration:const InputDecoration(labelText:'Texte du bouton')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:source,isExpanded:true,decoration:const InputDecoration(labelText:'Quels résultats ?'),items:const[
          DropdownMenuItem(value:'all',child:Text('Toutes compétitions')),
          DropdownMenuItem(value:'aml',child:Text('AML uniquement')),
          DropdownMenuItem(value:'competition',child:Text('Une compétition précise')),
        ],onChanged:(v)=>setD(()=>source=v??'all')),
        if(source=='competition')DropdownButtonFormField<String>(value:competitionId,isExpanded:true,decoration:const InputDecoration(labelText:'Compétition'),items:comps.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['name']??'Compétition').toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setD(()=>competitionId=v)),
        DropdownButtonFormField<int>(value:limit,decoration:const InputDecoration(labelText:'Nombre de résultats affichés'),items:[for(final n in [1,2,3,4,5,6,8,10])DropdownMenuItem<int>(value:n,child:Text('$n'))],onChanged:(v)=>setD(()=>limit=v??4)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Enregistrer'))],
    )));
    if(ok==true){
      setState((){section['title']=title.text.trim();section['action_label']=action.text.trim();section['content']=<String,dynamic>{'source':source,if(source=='competition'&&competitionId!=null)'competition_id':competitionId,'limit':limit};});
      await _save();
    }
    title.dispose(); action.dispose();
  }

  // « Classement AML » : classement officiel des combattants (par catégorie) ou classement XP des fans.
  Future<void> _editRankings(Map<String,dynamic> section) async {
    final cats=<Map<String,dynamic>>[];
    try{cats.addAll(await widget.repo.adminWeightCategories());}catch(_){}
    if(!mounted) return;
    final raw=section['content'] is Map?Map<String,dynamic>.from(section['content'] as Map):<String,dynamic>{};
    String source='fighters';
    String? categoryId=raw['category_id']?.toString(); if(categoryId!=null&&!cats.any((e)=>e['id'].toString()==categoryId)) categoryId=null;
    int limit=int.tryParse('${raw['limit']??5}')??5; if(limit<3)limit=3; if(limit>10)limit=10;
    final title=TextEditingController(text:section['title']?.toString()??'CLASSEMENTS AML'), action=TextEditingController(text:section['action_label']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      backgroundColor:_surface,
      title:const Text('Section « Classement AML »'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titre affiché')),
        TextField(controller:action,decoration:const InputDecoration(labelText:'Texte du bouton')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:source,isExpanded:true,decoration:const InputDecoration(labelText:'Quel classement ?'),items:const[
          DropdownMenuItem(value:'fighters',child:Text('Classement officiel des combattants')),
        ],onChanged:(v)=>setD(()=>source=v??'fighters')),
        if(source=='fighters')DropdownButtonFormField<String?>(value:categoryId,isExpanded:true,decoration:const InputDecoration(labelText:'Catégorie de poids'),items:[const DropdownMenuItem<String?>(value:null,child:Text('Toutes les catégories')),...cats.map((e)=>DropdownMenuItem<String?>(value:e['id'].toString(),child:Text((e['name']??'Catégorie').toString(),overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setD(()=>categoryId=v)),
        DropdownButtonFormField<int>(value:limit,decoration:const InputDecoration(labelText:'Nombre de lignes affichées'),items:[for(final n in [3,4,5,6,8,10])DropdownMenuItem<int>(value:n,child:Text('$n'))],onChanged:(v)=>setD(()=>limit=v??5)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Enregistrer'))],
    )));
    if(ok==true){
      setState((){section['title']=title.text.trim();section['action_label']=action.text.trim();section['content']=<String,dynamic>{'source':source,if(source=='fighters'&&categoryId!=null)'category_id':categoryId,'limit':limit};});
      await _save();
    }
    title.dispose(); action.dispose();
  }

  Future<void> _editNextFight(Map<String,dynamic> section) async {
    final events=<Map<String,dynamic>>[]; final comps=<Map<String,dynamic>>[];
    try{events.addAll(await widget.repo.adminEvents()); comps.addAll(await widget.repo.adminCompetitions());}catch(_){}
    if(!mounted) return;
    final raw=section['content'] is Map?Map<String,dynamic>.from(section['content'] as Map):<String,dynamic>{};
    String mode=(raw['mode']??'auto').toString(); if(!['auto','event','competition'].contains(mode)) mode='auto';
    String? eventId=raw['event_id']?.toString(); if(eventId!=null&&!events.any((e)=>e['id'].toString()==eventId)) eventId=null;
    String? competitionId=raw['competition_id']?.toString(); if(competitionId!=null&&!comps.any((e)=>e['id'].toString()==competitionId)) competitionId=null;
    int limit=int.tryParse('${raw['limit']??1}')??1; if(limit<1)limit=1; if(limit>5)limit=5;
    final title=TextEditingController(text:section['title']?.toString()??'PROCHAIN COMBAT'), action=TextEditingController(text:section['action_label']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      backgroundColor:_surface,
      title:const Text('Section « Prochain combat »'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titre affiché')),
        TextField(controller:action,decoration:const InputDecoration(labelText:'Texte du bouton')),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:mode,isExpanded:true,decoration:const InputDecoration(labelText:'Quoi afficher ?'),items:const[
          DropdownMenuItem(value:'auto',child:Text('Automatique (AML en priorité)')),
          DropdownMenuItem(value:'event',child:Text('Une carte précise')),
          DropdownMenuItem(value:'competition',child:Text('Une compétition (AML, UFC…)')),
        ],onChanged:(v)=>setD(()=>mode=v??'auto')),
        if(mode=='event')DropdownButtonFormField<String>(value:eventId,isExpanded:true,decoration:const InputDecoration(labelText:'Carte'),items:events.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['name']??'Événement').toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setD(()=>eventId=v)),
        if(mode=='competition')DropdownButtonFormField<String>(value:competitionId,isExpanded:true,decoration:const InputDecoration(labelText:'Compétition'),items:comps.map((e)=>DropdownMenuItem<String>(value:e['id'].toString(),child:Text((e['name']??'Compétition').toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setD(()=>competitionId=v)),
        DropdownButtonFormField<int>(value:limit,decoration:const InputDecoration(labelText:'Nombre de combats affichés'),items:[for(final n in [1,2,3,4,5])DropdownMenuItem<int>(value:n,child:Text('$n'))],onChanged:(v)=>setD(()=>limit=v??1)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Enregistrer'))],
    )));
    if(ok==true){
      setState((){section['title']=title.text.trim();section['action_label']=action.text.trim();section['content']=<String,dynamic>{'mode':mode,if(mode=='event'&&eventId!=null)'event_id':eventId,if(mode=='competition'&&competitionId!=null)'competition_id':competitionId,'limit':limit};});
      await _save();
    }
    title.dispose(); action.dispose();
  }

  Future<void> _editSection(Map<String,dynamic> section) async {
    if(section['section_key']=='next_fight'){ await _editNextFight(section); return; }
    if(section['section_key']=='results'){ await _editResults(section); return; }
    if(section['section_key']=='community_stats'){ await _editCommunityStats(section); return; }
    if(section['section_key']=='rankings'){ await _editRankings(section); return; }
    final title=TextEditingController(text:section['title']?.toString()??''), action=TextEditingController(text:section['action_label']?.toString()??''), description=TextEditingController(text:section['description']?.toString()??''), image=TextEditingController(text:section['image_url']?.toString()??'');
    final raw=section['content']; final content=TextEditingController(text:raw is Map?(raw as Map).entries.map((e)=>'${e.key}=${e.value}').join('\n'):'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:_surface,title:Text('Modifier ${section['section_key']}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Titre affiché')),TextField(controller:action,decoration:const InputDecoration(labelText:'Action / bouton')),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'Information métier / description')),TextField(controller:image,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'URL image')),TextField(controller:content,maxLines:4,decoration:const InputDecoration(labelText:'Données supplémentaires clé=valeur'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Enregistrer'))]));
    if(ok==true){final map=<String,dynamic>{};for(final line in content.text.split(RegExp(r'\r?\n'))){final i=line.indexOf('=');if(i>0)map[line.substring(0,i).trim()]=line.substring(i+1).trim();}setState((){section['title']=title.text.trim();section['action_label']=action.text.trim();section['description']=description.text.trim();section['image_url']=image.text.trim();section['content']=map;});await _save();}
    for(final c in [title,action,description,image,content])c.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator(color:_blue));
    return RefreshIndicator(color:_blue,onRefresh:_load,child:ListView(padding:const EdgeInsets.all(14),children:[
      Row(children:[const Expanded(child:Text('ACCUEIL DE L’APPLICATION',style:TextStyle(color:_blue,fontWeight:FontWeight.w900,letterSpacing:1))),OutlinedButton.icon(onPressed:_addSection,icon:const Icon(Icons.add,size:17),label:const Text('Ajouter'))]),
      const SizedBox(height:10),
      SwitchListTile(tileColor:_surface,title:const Text('Hero d’accueil'),subtitle:const Text('Afficher le bandeau principal'),value:settings['hero_enabled']!=false,onChanged:(v)=>setState(()=>settings['hero_enabled']=v)),
      TextField(controller:heroTitle,decoration:const InputDecoration(labelText:'Titre principal')),
      TextField(controller:heroSubtitle,decoration:const InputDecoration(labelText:'Sous-titre')),
      TextField(controller:heroImage,keyboardType:TextInputType.url,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'URL image du hero')),
      if(heroImage.text.trim().isNotEmpty)AmlUrlMediaPreview(url:heroImage.text.trim(),compact:true),
      const SizedBox(height:18),const Text('SECTIONS — CONTENU MÉTIER / VISIBILITÉ / ORDRE',style:TextStyle(color:_blue,fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:8),
      ...sections.map<Widget>((section) {
        final title = section['title']?.toString().trim().isNotEmpty == true
            ? section['title'].toString()
            : (section['section_key']?.toString() ?? 'Section');
        final description = section['description']?.toString().trim() ?? '';
        final subtitle = '${section['section_key'] ?? ''} • ordre ${section['sort_order'] ?? 100}'
            '${description.isNotEmpty ? '\n$description' : ''}';
        return Card(
          color: _surface,
          child: ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            leading: Switch(
              value: section['is_visible'] == true,
              onChanged: (value) => setState(() => section['is_visible'] = value),
            ),
            trailing: SizedBox(
              width: 150,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: (section['sort_order'] ?? 100).toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ordre'),
                      onChanged: (value) => section['sort_order'] = int.tryParse(value) ?? 100,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteSection(section),
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  ),
                ],
              ),
            ),
            onTap: () => _editSection(section),
          ),
        );
      }),
      const SizedBox(height:15),ElevatedButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('ENREGISTRER L’ACCUEIL'),style:ElevatedButton.styleFrom(backgroundColor:_blue)),
    ]));
  }
}

class _AdminFeature extends StatelessWidget { final IconData icon; final String title, subtitle; const _AdminFeature({required this.icon, required this.title, required this.subtitle}); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.only(bottom: 9), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15)), child: ListTile(leading: Icon(icon,color:_blue), title: Text(title,style:const TextStyle(fontWeight:FontWeight.w800)), subtitle: Text(subtitle,style:const TextStyle(color:Colors.white54)))); }
class _ComingSoonTab extends StatelessWidget { final IconData icon; final String title, subtitle; const _ComingSoonTab({required this.icon,required this.title,required this.subtitle}); @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:54,color:_blue),const SizedBox(height:18),Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900),textAlign:TextAlign.center),const SizedBox(height:8),Text(subtitle,style:const TextStyle(color:Colors.white54),textAlign:TextAlign.center)]))); }


class _EventsAdminTab extends StatelessWidget {
  const _EventsAdminTab();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.event_note_outlined, size: 58, color: _blue),
        const SizedBox(height: 16),
        const Text('Événements & combats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Créer les événements AML, construire les fight cards et programmer les combats.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlEventsAdminScreen())),
          icon: const Icon(Icons.event_outlined),
          label: const Text('OUVRIR LES ÉVÉNEMENTS', style: TextStyle(fontWeight: FontWeight.w900)),
          style: ElevatedButton.styleFrom(backgroundColor: _blue),
        ),
      ]),
    ),
  );
}

class _FighterAdminTab extends StatelessWidget {
  const _FighterAdminTab();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.sports_mma_outlined, size: 58, color: _blue),
        const SizedBox(height: 16),
        const Text('Gestion des Fighters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Créer, modifier, activer et vérifier les profils professionnels AML.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlFighterAdminScreen())),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('OUVRIR LA GESTION', style: TextStyle(fontWeight: FontWeight.w900)),
          style: ElevatedButton.styleFrom(backgroundColor: _blue),
        ),
      ]),
    ),
  );
}


class _TicketsAdminTab extends StatelessWidget {
  const _TicketsAdminTab();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.confirmation_number_outlined, size: 58, color: _blue),
        const SizedBox(height: 16),
        const Text('Billetterie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Gère les offres de billets liées aux événements officiels.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlTicketsAdminScreen())), icon: const Icon(Icons.confirmation_number_outlined), label: const Text('OUVRIR LA BILLETTERIE', style: TextStyle(fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: _blue)),
      ]),
    ),
  );
}
