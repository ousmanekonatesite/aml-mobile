import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';

const Color _usersBlue = Color(0xFF00AEEF);
const Color _usersBlack = Color(0xFF050505);
const Color _usersSurface = Color(0xFF111111);

class AmlUsersAdminScreen extends StatefulWidget {
  final AdminRepository repo;
  const AmlUsersAdminScreen({super.key, required this.repo});
  @override
  State<AmlUsersAdminScreen> createState() => _AmlUsersAdminScreenState();
}

class _AmlUsersAdminScreenState extends State<AmlUsersAdminScreen> {
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> users;
  bool busy = false;
  @override
  void initState() { super.initState(); users = widget.repo.adminUsers(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  void reload() => setState(() => users = widget.repo.adminUsers(search: search.text));

  Future<void> _edit(Map<String, dynamic> user) async {
    final displayName = TextEditingController(text: user['display_name']?.toString() ?? '');
    final username = TextEditingController(text: user['username']?.toString() ?? '');
    final values = await showDialog<Map<String,String>>(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor:_usersSurface, title:const Text('Modifier le profil'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:displayName,decoration:const InputDecoration(labelText:'Nom affiché')),TextField(controller:username,decoration:const InputDecoration(labelText:'Pseudo'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,{'displayName':displayName.text.trim(),'username':username.text.trim()}),child:const Text('Enregistrer'))],
    ));
    displayName.dispose(); username.dispose(); if(values==null)return;
    try { await widget.repo.updateUserProfile(user['id'].toString(),values['displayName']!,values['username']!); if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Profil mis à jour.')));reload();} } catch(e){_error(e);}
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_usersSurface,title:const Text('Supprimer définitivement ?'),content:Text('Le compte ${user['username'] ?? user['display_name'] ?? ''} sera supprimé. Cette action est irréversible.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annuler')),ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.red),onPressed:()=>Navigator.pop(ctx,true),child:const Text('Supprimer'))]));
    if(ok!=true)return;
    try { await widget.repo.deleteUser(user['id'].toString()); if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Compte supprimé.')));reload();} } catch(e){_error(e);}
  }

  Future<void> _role(Map<String, dynamic> user) async {
    const roles = <String, String>{'user':'Utilisateur','ticket_supervisor':'Superviseur billets','moderator':'Modérateur','editor':'Éditeur'};
    final current = user['role']?.toString() ?? 'user';
    final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      backgroundColor: _usersSurface, title: const Text('Attribuer un rôle'),
      children: roles.entries.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value))).toList(),
    ));
    if (selected == null) return;
    try { await widget.repo.setUserRole(user['id'].toString(), selected); if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rôle mis à jour.')));reload();} }
    catch(e){_error(e);}
  }

  Future<void> _balances(Map<String, dynamic> user) async {
    final credits = TextEditingController(text: '0');
    final xp = TextEditingController(text: '0');
    final reason = TextEditingController(text: 'Ajustement administrateur');
    final values = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _usersSurface, title: Text('Crédit et XP • ${user['display_name'] ?? user['username'] ?? 'Utilisateur'}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Montants positifs pour ajouter, négatifs pour retirer.'),
        TextField(controller: credits, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Variation de crédit AML')),
        TextField(controller: xp, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Variation XP')),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motif obligatoire')),
      ])),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annuler')), ElevatedButton(onPressed: ()=>Navigator.pop(ctx, {'credits':int.tryParse(credits.text)??0,'xp':int.tryParse(xp.text)??0,'reason':reason.text.trim()}), child: const Text('Appliquer'))],
    ));
    credits.dispose(); xp.dispose(); reason.dispose();
    if (values == null) return;
    if ((values['credits'] == 0 && values['xp'] == 0) || (values['reason'] as String).isEmpty) { _error('Indique un montant et un motif.'); return; }
    try { await widget.repo.adjustUserWallet(user['id'].toString(), values['credits'] as int, values['xp'] as int, values['reason'] as String); if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soldes mis à jour et mouvement enregistré.')));reload();} }
    catch(e){_error(e);}
  }

  Future<void> _suspend(Map<String, dynamic> user) async {
    final suspend = user['is_suspended'] != true;
    final ok = await showDialog<bool>(context: context, builder: (ctx)=>AlertDialog(backgroundColor:_usersSurface,title:Text(suspend?'Bannir cet utilisateur ?':'Réactiver cet utilisateur ?'),content:Text(suspend?'Il ne pourra plus utiliser son compte.':'L’accès au compte sera rétabli.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annuler')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(suspend?'Bannir':'Réactiver'))]));
    if(ok != true)return;
    try { await widget.repo.setUserSuspended(user['id'].toString(), suspend); if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(suspend?'Utilisateur banni.':'Utilisateur réactivé.')));reload();} }
    catch(e){_error(e);}
  }
  void _error(Object e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ','')))); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _usersBlack,
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children:[Expanded(child:TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Rechercher nom, pseudo ou identifiant',border:OutlineInputBorder()),onSubmitted:(_)=>reload())),IconButton(onPressed:reload,icon:const Icon(Icons.search,color:_usersBlue))])),
      const Padding(padding:EdgeInsets.symmetric(horizontal:14),child:Align(alignment:Alignment.centerLeft,child:Text('Gestion des comptes • rôles • crédit • XP',style:TextStyle(color:Colors.white60)))),
      const SizedBox(height:8),
      Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:users,builder:(context,snap){
        if(snap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator(color:_usersBlue));
        if(snap.hasError)return Center(child:Text('Erreur : ${snap.error}',textAlign:TextAlign.center));
        final rows=snap.data??[]; if(rows.isEmpty)return const Center(child:Text('Aucun utilisateur trouvé.'));
        return RefreshIndicator(color:_usersBlue,onRefresh:()async=>reload(),child:ListView.builder(itemCount:rows.length,itemBuilder:(context,i){final u=rows[i]; final banned=u['is_suspended']==true; final name=(u['display_name']??u['username']??'Utilisateur').toString(); return Card(color:_usersSurface,margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ExpansionTile(leading:CircleAvatar(backgroundColor:banned?Colors.redAccent:_usersBlue,child:Icon(banned?Icons.block:Icons.person,color:Colors.black)),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('@${u['username']??'—'} • ${u['role']??'user'}${banned?' • BANNI':''}',style:const TextStyle(color:Colors.white60)),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14),child:Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:()=>_edit(u),icon:const Icon(Icons.edit),label:const Text('Modifier')),OutlinedButton.icon(onPressed:()=>_role(u),icon:const Icon(Icons.admin_panel_settings),label:const Text('Rôle')),OutlinedButton.icon(onPressed:()=>_balances(u),icon:const Icon(Icons.account_balance_wallet),label:const Text('Crédit / XP')),OutlinedButton.icon(onPressed:()=>_suspend(u),icon:Icon(banned?Icons.lock_open:Icons.block),label:Text(banned?'Réactiver':'Bannir')),OutlinedButton.icon(onPressed:()=>_delete(u),icon:const Icon(Icons.delete_forever,color:Colors.redAccent),label:const Text('Supprimer'))]))]));}));
      }))
    ]),
  );
}
