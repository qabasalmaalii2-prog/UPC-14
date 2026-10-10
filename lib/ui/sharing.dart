import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../config.dart';
import '../data/store.dart';
import '../domain/calculator.dart';
import '../l10n/strings.dart';
import 'shell.dart';
import 'theme.dart';
String shareText(Map<String,dynamic> snapshot,String timestamp,String url){final d=Draft.fromJson(Map<String,dynamic>.from(snapshot['draft'] as Map)),r=snapshot['result'] as Map;final b=StringBuffer('Shared: $timestamp\nUPC — Umrah Package Calculator\n${d.name}\n');for(final stay in [d.madinah,d.makkah]){if(!stay.enabled){continue;}b.writeln('${stay.city.toUpperCase()} — ${stay.hotelName} (${stay.checkIn} → ${stay.checkOut})');for(final n in (r[stay.city]['nights'] as List)){b.writeln('${n['date']} ${n['type']} ${n['plan']} · ${n['quantity']} rooms × ${money(n['price'] as int)} SAR = ${money(n['total'] as int)} SAR');}b.writeln('City Total: ${money(r[stay.city]['total'] as int)} SAR');}for(final service in d.services){b.writeln('${service.name}: ${service.type.name} ${service.type==ServiceType.fixed?'': '${service.quantity} × '}${money(service.unitPrice)} SAR · ${service.deduct?'−':'+'}${money(service.total.abs())} SAR');}b.writeln('PACKAGE TOTAL: ${money(r['total'] as int)} SAR');if(r['usd']!=null){b.writeln('\$ ${r['usd']} (SAR per 1 USD: ${r['fx']})');}b.writeln('UPC — Umrah Package Calculator${url.isEmpty?'':' · $url'}');return b.toString();}
Future<void> openShare(BuildContext context,UpcStore store,Map<String,dynamic> snapshot)async {
  final s=Strings.of(context);
  final kind=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.image_outlined,color:green),title:Text('${s['share']} · Image'),onTap:()=>Navigator.pop(ctx,'image')),if(store.owner)ListTile(leading:const Icon(Icons.text_snippet_outlined,color:blue),title:Text('${s['share']} · Text (Owner)'),onTap:()=>Navigator.pop(ctx,'text'))])));
  if(kind==null||!context.mounted){return;}
  await runAction(context,()async {
    // Always reauthorize archive sharing as well: no cached-role security shortcut.
    final authorized=await store.client.rpc('authorize_share',params:{'p_snapshot':snapshot,'p_text':kind=='text'});
    if(authorized!=true){throw StateError('Share not authorized');}
    final url=store.appSettings['public_url'] as String? ?? Config.publicUrl;
    if(kind=='text'){await Share.share(shareText(snapshot,DateTime.now().toLocal().toIso8601String(),url));}
    else if(context.mounted){await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ShareImageScreen(snapshot,url)));}
  });
}
class ShareImageScreen extends StatefulWidget {
  final Map<String,dynamic> snapshot;final String url;
  const ShareImageScreen(this.snapshot,this.url,{super.key});
  @override State<ShareImageScreen> createState()=>_ShareImageScreenState();
}
class _ShareImageScreenState extends State<ShareImageScreen>{
  final captureKey=GlobalKey();String timestamp=DateTime.now().toLocal().toIso8601String();bool busy=false;
  Future<void> share()async{setState((){busy=true;timestamp=DateTime.now().toLocal().toIso8601String();});await runAction(context,()async{await WidgetsBinding.instance.endOfFrame;final boundary=captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;final image=await boundary.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();final dir=await getTemporaryDirectory(),file=File('${dir.path}/upc-${DateTime.now().millisecondsSinceEpoch}.png');await file.writeAsBytes(bytes!.buffer.asUint8List());try{await Share.shareXFiles([XFile(file.path,mimeType:'image/png')]);}finally{if(await file.exists()){await file.delete();}}});if(mounted){setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Share as Image'),actions:[IconButton(onPressed:busy?null:share,icon:const Icon(Icons.ios_share))]),body:SingleChildScrollView(child:Center(child:RepaintBoundary(key:captureKey,child:Container(width:390,color:const Color(0xfff5f8fa),padding:const EdgeInsets.all(12),child:SnapshotBody(widget.snapshot,sharedAt:timestamp,url:widget.url))))));
}
class SnapshotBody extends StatelessWidget {
  final Map<String,dynamic> snapshot;final String? savedAt,sharedAt;final String url;
  const SnapshotBody(this.snapshot,{super.key,this.savedAt,this.sharedAt,this.url=''});
  @override Widget build(BuildContext context){final d=Draft.fromJson(Map<String,dynamic>.from(snapshot['draft'] as Map)),r=snapshot['result'] as Map,s=Strings.of(context);return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(sharedAt!=null)Text('Shared: $sharedAt',style:const TextStyle(fontSize:10,color:Colors.grey)),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('UPC',style:TextStyle(color:navy,fontSize:26,fontWeight:FontWeight.w800)),const Text('Umrah Package Calculator',style:TextStyle(fontSize:12)),Text(d.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),Text(s[d.mode.name]),if(savedAt!=null)Text('${s['saved']}: ${DateTime.parse(savedAt!).toLocal()}',style:const TextStyle(fontSize:11))])),for(final stay in [d.madinah,d.makkah])if(stay.enabled)Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:stay.city=='madinah'?green:blue,borderRadius:BorderRadius.circular(7)),child:Text(s[stay.city],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),const SizedBox(height:8),Text(stay.hotelName,style:const TextStyle(fontWeight:FontWeight.bold)),Text('${stay.checkIn} → ${stay.checkOut} · ${stay.nights.length} ${s['nights']}'),Text('${s[d.mode==CalcMode.group?'pax':'guests']}: ${d.mode==CalcMode.group?stay.totalPax:stay.actualGuests}'),const Divider(),for(final n in (r[stay.city]['nights'] as List))Padding(padding:const EdgeInsets.only(bottom:5),child:Text('${n['date']} · ${n['type']} · ${n['plan']}\n${n['quantity']} × ${money(n['price'] as int)} SAR = ${money(n['total'] as int)} SAR',style:const TextStyle(fontSize:12))),Text('${s['cityTotal']}: ${money(r[stay.city]['total'] as int)} SAR',style:const TextStyle(fontWeight:FontWeight.bold))])),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:gold,borderRadius:BorderRadius.circular(7)),child:Text(s['services'],style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),const SizedBox(height:7),for(final service in d.services)Padding(padding:const EdgeInsets.only(bottom:6),child:Text('${service.name} · ${s[service.type.name]}\n${service.type==ServiceType.fixed?'': '${service.quantity} × '}${money(service.unitPrice)} SAR  ${service.deduct?'−':'+'}${money(service.total.abs())} SAR',style:const TextStyle(fontSize:12))),Text('${s['services']}: ${money(r['services'] as int)} SAR',style:const TextStyle(fontWeight:FontWeight.bold))])),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s['total'],style:const TextStyle(fontWeight:FontWeight.bold)),Text('${money(r['total'] as int)} SAR',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),Text(r['usd']==null?s['unavailable']:'\$ ${r['usd']}',style:const TextStyle(color:green,fontSize:21,fontWeight:FontWeight.bold)),Text('${s['fxLabel']}: ${r['fx']??'—'}',style:const TextStyle(fontSize:11))])),if(sharedAt!=null)Text('UPC — Umrah Package Calculator${url.isEmpty?'':' · $url'}',style:const TextStyle(fontSize:11))]);}
}
