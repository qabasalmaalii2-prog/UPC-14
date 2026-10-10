import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'ui/theme.dart';
import 'ui/shell.dart';
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();if(Config.configured){await Supabase.initialize(url:Config.supabaseUrl,anonKey:Config.supabaseKey);}runApp(MaterialApp(title:'UPC Administration',debugShowCheckedModeBanner:false,theme:upcTheme(false),home:Config.configured?const AdminPortal():const Scaffold(body:Center(child:Text('Configure SUPABASE_URL and SUPABASE_ANON_KEY.')))));}
class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key});
  @override State<AdminPortal> createState()=>_AdminPortalState();
}
class _AdminPortalState extends State<AdminPortal>{
  final email=TextEditingController(),password=TextEditingController(),search=TextEditingController();
  final client=Supabase.instance.client;
  Map<String,dynamic>? metrics;
  List<Map<String,dynamic>> users=[],logs=[],feedback=[];
  String? role,error;String section='Dashboard';
  @override void initState(){super.initState();if(client.auth.currentUser!=null){load();}}
  @override void dispose(){email.dispose();password.dispose();search.dispose();super.dispose();}
  Future<void> load()async{try{final a=await client.from('accounts').select('role').eq('id',client.auth.currentUser!.id).single();role=a['role'] as String;final m=await client.rpc('admin_overview');metrics=Map<String,dynamic>.from(m as Map);await fetchUsers();if(['OWNER','ADMIN','SUPPORT'].contains(role)){final f=await client.rpc('admin_feedback');feedback=(f as List).map((j)=>Map<String,dynamic>.from(j as Map)).toList();}if(['OWNER','ADMIN','ANALYST'].contains(role)){final l=await client.rpc('admin_audit');logs=(l as List).map((j)=>Map<String,dynamic>.from(j as Map)).toList();}error=null;}catch(e){error=e.toString();}if(mounted){setState((){});}}
  Future<void> fetchUsers()async{final r=await client.rpc('admin_users',params:{'p_query':search.text,'p_limit':100});users=(r as List).map((j)=>Map<String,dynamic>.from(j as Map)).toList();}
  @override Widget build(BuildContext context){if(client.auth.currentUser==null){return Scaffold(backgroundColor:navy,body:Center(child:SizedBox(width:380,child:Panel(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('UPC · OWNER / ADMIN',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:16),TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:8),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password')),const SizedBox(height:16),ElevatedButton(onPressed:()=>runAction(context,()async{await client.auth.signInWithPassword(email:email.text,password:password.text);await load();if(mounted){setState((){});}}),child:const Text('Sign In'))])))));}
    final sections=['Dashboard','Users','Premium & Grants','App Management','Security & Audit','Support & Feedback'];
    return Scaffold(appBar:AppBar(title:const Text('UPC — Administration'),actions:[IconButton(tooltip:'Refresh',onPressed:load,icon:const Icon(Icons.refresh)),IconButton(tooltip:'Log Out',onPressed:()async{await client.auth.signOut();if(mounted){setState(()=>metrics=null);}},icon:const Icon(Icons.logout))]),body:LayoutBuilder(builder:(context,size){final content=ListView(padding:const EdgeInsets.all(20),children:[Text(section,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:16),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),if(metrics!=null)Wrap(spacing:10,runSpacing:10,children:metrics!.entries.map((e)=>SizedBox(width:190,child:Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.key.replaceAll('_',' ').toUpperCase(),style:const TextStyle(fontSize:12)),Text('${e.value}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold,color:green))])))).toList()),if(section=='Dashboard')const Panel(child:Text('Live account, trial, entitlement and usage counts are returned by the backend. Revenue, login analytics and trend charts are not yet implemented; no illustrative statistics are shown.')),if(section=='Users'||section=='Premium & Grants')...[
      Panel(child:Row(children:[Expanded(child:TextField(controller:search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search name or email'))),TextButton(onPressed:()=>runAction(context,()async{await fetchUsers();if(mounted){setState((){});}}),child:const Text('Search'))])),
      ...users.map((u)=>Panel(child:Wrap(alignment:WrapAlignment.spaceBetween,spacing:10,runSpacing:10,children:[SizedBox(width:320,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u['full_name'] as String? ?? '',style:const TextStyle(fontWeight:FontWeight.bold)),Text(u['email'] as String? ?? ''),Text('${u['role']} · ${u['status']} · Trial: ${u['trial_ends_at']}'),Text('Premium: ${u['premium_until']??'—'} / Permanent: ${u['permanent']}')])),if(['OWNER','ADMIN'].contains(role))Wrap(spacing:6,children:[for(final status in ['active','suspended','blocked'])OutlinedButton(onPressed:()=>runAction(context,()async{await client.rpc('admin_set_status',params:{'p_user':u['id'],'p_status':status});await load();}),child:Text(status)),if(role=='OWNER')PopupMenuButton<String>(tooltip:'Grant Premium',onSelected:(plan)=>runAction(context,()async{await client.rpc('owner_grant',params:{'p_user':u['id'],'p_plan':plan});await load();}),itemBuilder:(_)=>['1m','6m','1y','unlimited','remove'].map((p)=>PopupMenuItem(value:p,child:Text(p))).toList(),child:const Padding(padding:EdgeInsets.all(12),child:Text('Grant Premium',style:TextStyle(color:gold,fontWeight:FontWeight.bold))))])])))
    ],if(section=='App Management')AppConfigEditor(client,role=='OWNER'),if(section=='Security & Audit')...logs.map((l)=>Panel(child:Text('${l['created_at']} · ${l['action']} · ${l['subject_id']}\n${l['detail']}'))),if(section=='Support & Feedback')...feedback.map((f)=>Panel(child:Text('${f['kind']} · ${f['created_at']}\n${f['body']}'))),const SizedBox(height:12),const Text('Separate web dashboard. No central hotel catalogue or private calculation browsing.',style:TextStyle(color:Colors.grey))]);
      final nav=Container(width:230,color:navy,child:Column(children:[const Padding(padding:EdgeInsets.all(24),child:Text('UPC',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w800))),...sections.map((title)=>ListTile(selected:section==title,selectedTileColor:green,title:Text(title,style:const TextStyle(color:Colors.white)),onTap:()=>setState(()=>section=title))),const Spacer(),Padding(padding:const EdgeInsets.all(16),child:Text(role??'Checking privileges',style:const TextStyle(color:Colors.white70)))]));
      return size.maxWidth>850?Row(children:[nav,Expanded(child:content)]):Column(children:[DropdownButton<String>(value:section,items:sections.map((title)=>DropdownMenuItem(value:title,child:Text(title))).toList(),onChanged:(v)=>setState(()=>section=v!)),Expanded(child:content)]);
    }));
  }
}
class AppConfigEditor extends StatefulWidget {
  final SupabaseClient client;final bool editable;
  const AppConfigEditor(this.client,this.editable,{super.key});
  @override State<AppConfigEditor> createState()=>_AppConfigEditorState();
}
class _AppConfigEditorState extends State<AppConfigEditor>{
  final fields={for(final k in ['public_url','support_email','support_phone'])k:TextEditingController()};
  @override void initState(){super.initState();load();}
  Future<void> load()async{final row=await widget.client.from('app_settings').select().eq('id',1).single();for(final e in fields.entries){e.value.text=row['body'][e.key] as String? ?? '';}}
  @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>Panel(child:Column(children:[for(final e in fields.entries)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:e.value,readOnly:!widget.editable,decoration:InputDecoration(labelText:e.key))),if(widget.editable)ElevatedButton(onPressed:()=>runAction(context,()=>widget.client.rpc('owner_configure',params:{'p_body':fields.map((k,c)=>MapEntry(k,c.text.trim()))}).then((_){ })),child:const Text('Save Configuration')),const Text('Announcements, audience-targeted partner offers and plan product configuration remain incomplete.') ]));
}
