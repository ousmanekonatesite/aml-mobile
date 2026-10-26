import 'package:flutter/material.dart';
import '../../widgets_url_media_preview.dart';
import '../../services/admin_repository.dart';

const Color _eventBlue = Color(0xFF00AEEF);
const Color _eventBlack = Color(0xFF050505);
const Color _eventSurface = Color(0xFF111111);

class AmlEventsAdminScreen extends StatefulWidget {
  const AmlEventsAdminScreen({super.key});
  @override State<AmlEventsAdminScreen> createState() => _AmlEventsAdminScreenState();
}

class _AmlEventsAdminScreenState extends State<AmlEventsAdminScreen> {
  final AdminRepository repo = AdminRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() { super.initState(); future = repo.adminEvents(); }
  void reload() => setState(() => future = repo.adminEvents());

  Future<void> edit([Map<String, dynamic>? event]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _eventSurface,
      builder: (_) => _EventForm(repo: repo, event: event),
    );
    if (changed == true) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _eventBlack,
    appBar: AppBar(
      backgroundColor: _eventBlack,
      title: const Text('Événements AML', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [IconButton(onPressed: () => edit(), icon: const Icon(Icons.add, color: _eventBlue))],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _eventBlue));
        if (snapshot.hasError) return _ErrorView(message: '${snapshot.error}', onRetry: reload);
        final events = snapshot.data ?? [];
        if (events.isEmpty) return _EmptyView(onAdd: () => edit());
        return RefreshIndicator(
          color: _eventBlue, onRefresh: () async => reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(14), itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              final status = e['status']?.toString() ?? 'draft';
              return Card(
                color: _eventSurface, margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: _eventBlue.withOpacity(.12), child: const Icon(Icons.event, color: _eventBlue)),
                  title: Text(e['name']?.toString() ?? 'Événement', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${e['city'] ?? 'Lieu à définir'} • ${_statusLabel(status)}', style: const TextStyle(color: Colors.white54)),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'fights') {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => AmlEventFightsAdminScreen(event: e, repo: repo)));
                        reload();
                      } else if (value == 'edit') {
                        edit(e);
                      } else if (value == 'delete') {
                        final ok = await _confirmDelete(e['name']?.toString() ?? 'cet événement');
                        if (ok) { await repo.deleteEvent(e['id'].toString()); reload(); }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'fights', child: Text('Gérer les combats')),
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmlEventFightsAdminScreen(event: e, repo: repo))),
                ),
              );
            },
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton(onPressed: () => edit(), backgroundColor: _eventBlue, child: const Icon(Icons.add, color: Colors.white)),
  );

  Future<bool> _confirmDelete(String name) async => await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer l’événement ?'),
      content: Text('« $name » sera supprimé. Les combats associés seront dissociés.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))],
    ),
  ) ?? false;

  String _statusLabel(String value) => const {
    'draft': 'Brouillon', 'published': 'Publié', 'live': 'En direct', 'finished': 'Terminé', 'cancelled': 'Annulé'
  }[value] ?? value;
}

class AmlEventFightsAdminScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final AdminRepository repo;
  const AmlEventFightsAdminScreen({super.key, required this.event, required this.repo});
  @override State<AmlEventFightsAdminScreen> createState() => _AmlEventFightsAdminScreenState();
}

class _AmlEventFightsAdminScreenState extends State<AmlEventFightsAdminScreen> {
  late Future<List<Map<String, dynamic>>> future;
  List<Map<String, dynamic>> fighters = [];
  List<Map<String, dynamic>> weights = [];

  @override
  void initState() { super.initState(); future = widget.repo.adminFights(widget.event['id'].toString()); _loadLists(); }

  Future<void> _loadLists() async {
    final results = await Future.wait([widget.repo.adminFighters(), widget.repo.adminWeightCategories()]);
    if (mounted) setState(() { fighters = results[0]; weights = results[1]; });
  }
  void reload() => setState(() => future = widget.repo.adminFights(widget.event['id'].toString()));

  Future<void> addFight([Map<String, dynamic>? fight]) async {
    if (fighters.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il faut au moins 2 fighters actifs pour créer un combat.')));
      return;
    }
    final changed = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _eventSurface,
      builder: (_) => _FightForm(repo: widget.repo, eventId: widget.event['id'].toString(), fighters: fighters, weights: weights, fight: fight),
    );
    if (changed == true) reload();
  }

  String fighterName(String? id) {
    final f = fighters.where((x) => x['id']?.toString() == id).firstOrNull;
    if (f == null) return 'Fighter';
    return '${f['first_name'] ?? ''} ${f['last_name'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _eventBlack,
    appBar: AppBar(backgroundColor: _eventBlack, title: Text(widget.event['name']?.toString() ?? 'Combats'), actions: [IconButton(onPressed: () => addFight(), icon: const Icon(Icons.add, color: _eventBlue))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _eventBlue));
        if (snapshot.hasError) return _ErrorView(message: '${snapshot.error}', onRetry: reload);
        final fights = snapshot.data ?? [];
        if (fights.isEmpty) return _EmptyFightView(onAdd: () => addFight());
        return RefreshIndicator(color: _eventBlue, onRefresh: () async => reload(), child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: fights.length, itemBuilder: (_, i) {
          final f = fights[i];
          final a = fighterName(f['fighter_a_id']?.toString());
          final b = fighterName(f['fighter_b_id']?.toString());
          return Card(color: _eventSurface, margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            leading: CircleAvatar(backgroundColor: _eventBlue.withOpacity(.12), child: Text('${(f['bout_order'] as num?)?.toInt() ?? i + 1}', style: const TextStyle(color: _eventBlue, fontWeight: FontWeight.w900))),
            title: Text('$a  VS  $b', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${f['title_bout'] == true ? 'MAIN EVENT • ' : ''}${f['status'] ?? 'scheduled'} • ${f['scheduled_rounds'] ?? 3} rounds', style: const TextStyle(color: Colors.white54)),
            trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') addFight(f); if (v == 'delete') { await widget.repo.deleteFight(f['id'].toString()); reload(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Modifier')), PopupMenuItem(value: 'delete', child: Text('Supprimer'))]),
          ));
        }));
      },
    ),
    floatingActionButton: FloatingActionButton(onPressed: () => addFight(), backgroundColor: _eventBlue, child: const Icon(Icons.add, color: Colors.white)),
  );
}

class _EventForm extends StatefulWidget {
  final AdminRepository repo; final Map<String, dynamic>? event;
  const _EventForm({required this.repo, this.event});
  @override State<_EventForm> createState() => _EventFormState();
}
class _EventFormState extends State<_EventForm> {
  late final TextEditingController name, slug, city, venue, description, poster, cover;
  String status = 'draft'; bool saving = false; DateTime? startsAt;
  List<Map<String, dynamic>> competitions = []; String? competitionId;
  @override void initState() { super.initState(); final e = widget.event ?? {}; startsAt = DateTime.tryParse(e['starts_at']?.toString() ?? '')?.toLocal(); name=TextEditingController(text:e['name']?.toString()); slug=TextEditingController(text:e['slug']?.toString()); city=TextEditingController(text:e['city']?.toString()); venue=TextEditingController(text:e['venue_name']?.toString()); description=TextEditingController(text:e['description']?.toString()); poster=TextEditingController(text:e['poster_url']?.toString()); cover=TextEditingController(text:e['cover_url']?.toString()); status=e['status']?.toString() ?? 'draft'; competitionId=e['competition_id']?.toString(); _loadCompetitions(); }
  Future<void> _loadCompetitions() async { try { final list = await widget.repo.adminCompetitions(); if(!mounted) return; setState((){ competitions = list; if(competitionId==null && list.isNotEmpty){ final aml = list.where((c)=>c['is_aml']==true).toList(); competitionId = (aml.isNotEmpty ? aml.first : list.first)['id'].toString(); } }); } catch(_){} }
  @override void dispose(){ for(final c in [name,slug,city,venue,description,poster,cover]) c.dispose(); super.dispose(); }
  Future<void> save() async {
    if(name.text.trim().isEmpty || slug.text.trim().isEmpty) return;
    setState(()=>saving=true);
    try { await widget.repo.saveEvent({'name':name.text.trim(),'slug':slug.text.trim().toLowerCase(),'city':city.text.trim().isEmpty?null:city.text.trim(),'venue_name':venue.text.trim().isEmpty?null:venue.text.trim(),'description':description.text.trim().isEmpty?null:description.text.trim(),'poster_url':poster.text.trim().isEmpty?null:poster.text.trim(),'cover_url':cover.text.trim().isEmpty?null:cover.text.trim(),'starts_at':startsAt?.toUtc().toIso8601String(),'status':status,'competition_id':competitionId}, widget.event?['id']?.toString()); if(mounted) Navigator.pop(context,true); }
    catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enregistrement impossible : $e'))); }
    finally{ if(mounted) setState(()=>saving=false); }
  }
  @override Widget build(BuildContext context) { final bottom=MediaQuery.of(context).viewInsets.bottom; return Padding(padding:EdgeInsets.fromLTRB(18,18,18,bottom+18),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.event==null?'Nouvel événement':'Modifier l’événement',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),TextField(controller:name,decoration:const InputDecoration(labelText:'Nom')),TextField(controller:slug,decoration:const InputDecoration(labelText:'Slug public')),if(competitions.isNotEmpty)DropdownButtonFormField<String>(value:competitions.any((c)=>c['id'].toString()==competitionId)?competitionId:null,isExpanded:true,decoration:const InputDecoration(labelText:'Compétition (AML, UFC, autres)'),items:competitions.map((c)=>DropdownMenuItem<String>(value:c['id'].toString(),child:Text((c['name']??'Compétition').toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>competitionId=v)),Row(children:[Expanded(child:TextField(controller:city,decoration:const InputDecoration(labelText:'Ville'))),const SizedBox(width:10),Expanded(child:TextField(controller:venue,decoration:const InputDecoration(labelText:'Lieu')))]),TextField(controller:description,decoration:const InputDecoration(labelText:'Description'),maxLines:3),const SizedBox(height:8),OutlinedButton.icon(onPressed:() async { final now=DateTime.now(); final pickedDate=await showDatePicker(context:context,initialDate:startsAt??now,firstDate:DateTime(now.year-1),lastDate:DateTime(now.year+8)); if(pickedDate==null||!mounted)return; final pickedTime=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(startsAt??DateTime(pickedDate.year,pickedDate.month,pickedDate.day,18))); if(pickedTime==null||!mounted)return; setState(()=>startsAt=DateTime(pickedDate.year,pickedDate.month,pickedDate.day,pickedTime.hour,pickedTime.minute)); },icon:const Icon(Icons.calendar_month),label:Text(startsAt==null?'Définir date et heure de l’événement':'Date : ${startsAt!.day.toString().padLeft(2,'0')}/${startsAt!.month.toString().padLeft(2,'0')}/${startsAt!.year} • ${startsAt!.hour.toString().padLeft(2,'0')}:${startsAt!.minute.toString().padLeft(2,'0')}')),TextField(controller:poster,decoration:const InputDecoration(labelText:'URL affiche'),onChanged:(_)=>setState((){})),if(poster.text.trim().isNotEmpty) AmlUrlMediaPreview(url:poster.text.trim(),compact:true),TextField(controller:cover,decoration:const InputDecoration(labelText:'URL couverture'),onChanged:(_)=>setState((){})),if(cover.text.trim().isNotEmpty) AmlUrlMediaPreview(url:cover.text.trim(),compact:true),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Statut'),items:const [DropdownMenuItem(value:'draft',child:Text('Brouillon')),DropdownMenuItem(value:'published',child:Text('Publié')),DropdownMenuItem(value:'live',child:Text('En direct')),DropdownMenuItem(value:'finished',child:Text('Terminé')),DropdownMenuItem(value:'cancelled',child:Text('Annulé'))],onChanged:(v)=>setState(()=>status=v??'draft')),const SizedBox(height:14),SizedBox(width:double.infinity,height:50,child:ElevatedButton(onPressed:saving?null:save,style:ElevatedButton.styleFrom(backgroundColor:_eventBlue),child:saving?const CircularProgressIndicator(color:Colors.white):const Text('ENREGISTRER',style:TextStyle(fontWeight:FontWeight.w900))))]))); }
}

class _FightForm extends StatefulWidget {
  final AdminRepository repo; final String eventId; final List<Map<String,dynamic>> fighters, weights; final Map<String,dynamic>? fight;
  const _FightForm({required this.repo,required this.eventId,required this.fighters,required this.weights,this.fight});
  @override State<_FightForm> createState()=>_FightFormState();
}
class _FightFormState extends State<_FightForm>{
  List<Map<String,dynamic>> weightsLocal=[];
  String? a,b,weight,status='scheduled',winner,decisionType; final resultController = TextEditingController(); bool titleBout=false,saving=false; int rounds=3,boutOrder=1; int? finishRound;
  @override void initState(){super.initState();weightsLocal=List<Map<String,dynamic>>.from(widget.weights);final f=widget.fight;if(f!=null){a=f['fighter_a_id']?.toString();b=f['fighter_b_id']?.toString();weight=f['weight_category_id']?.toString();status=f['status']?.toString()??'scheduled';titleBout=f['title_bout']==true;rounds=(f['scheduled_rounds'] as num?)?.toInt()??3;boutOrder=(f['bout_order'] as num?)?.toInt()??1;winner=f['winner_fighter_id']?.toString();decisionType=f['decision_type']?.toString();resultController.text=f['result']?.toString()??'';finishRound=(f['finish_round'] as num?)?.toInt();}}
  @override void dispose(){resultController.dispose();super.dispose();}
  Future<void> addWeight() async {
    final name=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Nouvelle catégorie de poids'),content:TextField(controller:name,autofocus:true,decoration:const InputDecoration(labelText:'Nom (ex. Poids moyen)')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Créer'))]));
    final value=name.text.trim(); name.dispose();
    if(ok!=true||value.isEmpty)return;
    try{await widget.repo.saveWeightCategory(value);final list=await widget.repo.adminWeightCategories();if(!mounted)return;setState((){weightsLocal=list;final m=list.where((w)=>w['name']==value).toList();if(m.isNotEmpty)weight=m.first['id'].toString();});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Création impossible : $e')));}
  }
  Future<void> save() async {if(a==null||b==null||a==b)return;if(winner!=null && winner!=a && winner!=b) winner=null;setState(()=>saving=true);try{await widget.repo.saveFight({'event_id':widget.eventId,'fighter_a_id':a,'fighter_b_id':b,'weight_category_id':weight,'scheduled_rounds':rounds,'bout_order':boutOrder,'title_bout':titleBout,'status':status,'winner_fighter_id':winner,'result':resultController.text.trim().isEmpty?null:resultController.text.trim(),'finish_round':finishRound,'decision_type':decisionType},widget.fight?['id']?.toString());if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enregistrement impossible : $e')));}finally{if(mounted)setState(()=>saving=false);}}
  @override Widget build(BuildContext context){final bottom=MediaQuery.of(context).viewInsets.bottom;return Padding(padding:EdgeInsets.fromLTRB(18,18,18,bottom+18),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.fight==null?'Nouveau combat':'Modifier le combat',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),DropdownButtonFormField<String>(value:a,decoration:const InputDecoration(labelText:'Fighter A'),items:widget.fighters.map((f)=>DropdownMenuItem(value:f['id'].toString(),child:Text('${f['first_name']??''} ${f['last_name']??''}'.trim()))).toList(),onChanged:(v)=>setState(()=>a=v)),DropdownButtonFormField<String>(value:b,decoration:const InputDecoration(labelText:'Fighter B'),items:widget.fighters.map((f)=>DropdownMenuItem(value:f['id'].toString(),child:Text('${f['first_name']??''} ${f['last_name']??''}'.trim()))).toList(),onChanged:(v)=>setState(()=>b=v)),DropdownButtonFormField<String>(value:weight,decoration:const InputDecoration(labelText:'Catégorie de poids'),items:weightsLocal.map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name'].toString()))).toList(),onChanged:(v)=>setState(()=>weight=v)),Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:addWeight,icon:const Icon(Icons.add,size:16),label:const Text('Nouvelle catégorie de poids'))),TextFormField(initialValue:boutOrder.toString(),keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Ordre sur la carte'),onChanged:(v)=>boutOrder=int.tryParse(v.trim())??boutOrder),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Statut'),items:const [DropdownMenuItem(value:'scheduled',child:Text('Programmé')),DropdownMenuItem(value:'live',child:Text('En direct')),DropdownMenuItem(value:'finished',child:Text('Terminé')),DropdownMenuItem(value:'cancelled',child:Text('Annulé'))],onChanged:(v)=>setState(()=>status=v??'scheduled')),DropdownButtonFormField<String>(value:winner,decoration:const InputDecoration(labelText:'Vainqueur (résultat officiel)'),items:[const DropdownMenuItem<String>(value:null,child:Text('À déterminer / égalité')), ...widget.fighters.where((f)=>[a,b].contains(f['id'].toString())).map((f)=>DropdownMenuItem<String>(value:f['id'].toString(),child:Text('${f['first_name']??''} ${f['last_name']??''}'.trim())))],onChanged:(v)=>setState(()=>winner=v)),TextField(controller:resultController,decoration:const InputDecoration(labelText:'Résultat / méthode de victoire',hintText:'Ex. KO, décision unanime, égalité')),DropdownButtonFormField<String>(value:decisionType,decoration:const InputDecoration(labelText:'Type de décision'),items:const [DropdownMenuItem(value:null,child:Text('Non précisé')),DropdownMenuItem(value:'ko',child:Text('KO / TKO')),DropdownMenuItem(value:'submission',child:Text('Soumission')),DropdownMenuItem(value:'decision',child:Text('Décision')),DropdownMenuItem(value:'draw',child:Text('Égalité')),DropdownMenuItem(value:'other',child:Text('Autre'))],onChanged:(v)=>setState(()=>decisionType=v)),DropdownButtonFormField<int>(value:finishRound,decoration:const InputDecoration(labelText:'Round de fin (facultatif)'),items:[const DropdownMenuItem<int>(value:null,child:Text('Non précisé')), ...List.generate(rounds,(i)=>DropdownMenuItem<int>(value:i+1,child:Text('Round ${i+1}')))],onChanged:(v)=>setState(()=>finishRound=v)),DropdownButtonFormField<int>(value:rounds,decoration:const InputDecoration(labelText:'Rounds'),items:[3,5].map((v)=>DropdownMenuItem(value:v,child:Text('$v rounds'))).toList(),onChanged:(v)=>setState(()=>rounds=v??3)),SwitchListTile(contentPadding:EdgeInsets.zero,value:titleBout,onChanged:(v)=>setState(()=>titleBout=v),title:const Text('Combat pour le titre')),const SizedBox(height:8),SizedBox(width:double.infinity,height:50,child:ElevatedButton(onPressed:saving?null:save,style:ElevatedButton.styleFrom(backgroundColor:_eventBlue),child:saving?const CircularProgressIndicator(color:Colors.white):const Text('ENREGISTRER',style:TextStyle(fontWeight:FontWeight.w900))))])));}
}

class _EmptyView extends StatelessWidget { final VoidCallback onAdd; const _EmptyView({required this.onAdd}); @override Widget build(BuildContext c)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.event_outlined,size:58,color:_eventBlue),const SizedBox(height:14),const Text('Aucun événement',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:12),ElevatedButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('CRÉER UN ÉVÉNEMENT'))])); }
class _EmptyFightView extends StatelessWidget { final VoidCallback onAdd; const _EmptyFightView({required this.onAdd}); @override Widget build(BuildContext c)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.sports_mma_outlined,size:58,color:_eventBlue),const SizedBox(height:14),const Text('Aucun combat',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:12),ElevatedButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('AJOUTER UN COMBAT'))])); }
class _ErrorView extends StatelessWidget { final String message; final VoidCallback onRetry; const _ErrorView({required this.message,required this.onRetry}); @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.error_outline,size:54,color:Colors.orange),const SizedBox(height:14),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),const SizedBox(height:14),ElevatedButton(onPressed:onRetry,child:const Text('RÉESSAYER'))]))); }
