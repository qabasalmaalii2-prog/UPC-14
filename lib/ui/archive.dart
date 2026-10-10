import 'package:flutter/material.dart';
import '../data/store.dart';
import '../domain/calculator.dart';
import '../l10n/strings.dart';
import 'sharing.dart';
import 'shell.dart';
import 'theme.dart';
class ArchiveScreen extends StatefulWidget {
  final UpcStore store;
  const ArchiveScreen(this.store,{super.key});
  @override State<ArchiveScreen> createState()=>_ArchiveScreenState();
}
class _ArchiveScreenState extends State<ArchiveScreen>{
  String filter='all',query='';bool newest=true;
  @override Widget build(BuildContext context){final s=Strings.of(context);final items=widget.store.archive.where((a){final d=a['snapshot']['draft'] as Map;return(filter=='all'||d['mode']==filter)&&(d['name'] as String).toLowerCase().contains(query.toLowerCase());}).toList();if(!newest){items.setAll(0,items.reversed.toList());}return ListView(padding:const EdgeInsets.all(10),children:[Panel(child:Column(children:[TextField(decoration:InputDecoration(hintText:s['search'],prefixIcon:const Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v)),Row(children:['all','group','individual'].map((v)=>Expanded(child:TextButton(onPressed:()=>setState(()=>filter=v),child:Text(s[v],style:TextStyle(fontWeight:filter==v?FontWeight.bold:FontWeight.normal,color:filter==v?blue:null))))).toList()),TextButton.icon(onPressed:()=>setState(()=>newest=!newest),icon:const Icon(Icons.sort),label:Text(newest?'Newest First':'Oldest First'))])),if(items.isEmpty)Text(s['noRecords']),...items.map((a){final snap=a['snapshot'] as Map,d=Draft.fromJson(Map<String,dynamic>.from(snap['draft'] as Map)),r=snap['result'] as Map;return Panel(child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ArchiveDetail(widget.store,a))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(backgroundColor:d.mode==CalcMode.group?blue.withValues(alpha:.12):Colors.purple.withValues(alpha:.12),child:Icon(d.mode==CalcMode.group?Icons.groups:Icons.person,color:d.mode==CalcMode.group?blue:Colors.purple)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(d.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(s[d.mode.name],style:const TextStyle(fontSize:12)),if(d.madinah.enabled)Text('${s['madinah']} · ${d.mode==CalcMode.group?d.madinah.totalPax:d.madinah.actualGuests} pax'),if(d.makkah.enabled)Text('${s['makkah']} · ${d.mode==CalcMode.group?d.makkah.totalPax:d.makkah.actualGuests} pax'),Wrap(spacing:8,children:[Text('${money(r['total'] as int)} SAR',style:const TextStyle(fontWeight:FontWeight.bold)),if(r['usd']!=null)Text('\$ ${r['usd']}',style:const TextStyle(color:green,fontWeight:FontWeight.bold))]),Text('${s['saved']}: ${DateTime.parse(a['saved_at'] as String).toLocal()}',style:const TextStyle(fontSize:11))])),const Icon(Icons.chevron_right)])));})]);}
}
class ArchiveDetail extends StatelessWidget {
  final UpcStore store;final Map<String,dynamic> entry;
  const ArchiveDetail(this.store,this.entry,{super.key});
  @override Widget build(BuildContext context){final snap=Map<String,dynamic>.from(entry['snapshot'] as Map),s=Strings.of(context);return Scaffold(appBar:AppBar(title:Text(s['details'])),body:ListView(padding:const EdgeInsets.all(12),children:[SnapshotBody(snap,savedAt:entry['saved_at'] as String?),Wrap(spacing:8,runSpacing:8,children:[ElevatedButton.icon(onPressed:()=>runAction(context,()async{if(store.draft.nonempty&&!await askConfirm(context,s['discard'])){return;}await store.duplicate(entry);if(context.mounted){Navigator.pop(context);}}),icon:const Icon(Icons.copy),label:Text(s['duplicate'])),OutlinedButton.icon(onPressed:()=>openShare(context,store,snap),icon:const Icon(Icons.ios_share),label:Text(s['share'])),OutlinedButton.icon(onPressed:()=>runAction(context,()async{if(await askConfirm(context,s['deleteConfirm'])){await store.deleteArchive(entry['id'] as String);if(context.mounted){Navigator.pop(context);}}}),icon:const Icon(Icons.delete_outline,color:Colors.red),label:Text(s['delete'],style:const TextStyle(color:Colors.red)))]) ]));}
}
