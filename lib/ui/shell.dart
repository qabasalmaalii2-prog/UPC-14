import 'package:flutter/material.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import 'calculator_screen.dart';
import 'hotels.dart';
import 'archive.dart';
import 'settings.dart';
class Shell extends StatefulWidget {
  final UpcStore store;
  const Shell(this.store,{super.key});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell> {
  int index=0;bool prompted=false;
  @override Widget build(BuildContext context) {
    final s=Strings.of(context),store=widget.store;
    if(!store.busy&&!prompted&&store.needsContinue){prompted=true;WidgetsBinding.instance.addPostFrameCallback((_)async{
      if(!mounted){return;}
      final start=await showDialog<bool>(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(title:Text(s['unsaved']),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s['continue'])),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s['startNew']))]));
      if(start==true&&mounted){final ok=await askConfirm(context,s['discard']);if(ok){await store.newDraft();}}store.needsContinue=false;
    });}
    return Scaffold(appBar:AppBar(title:Column(children:[Text(index==0?'UPC':s[['calculator','hotels','archive','settings'][index]]),if(index==0)const Text('Umrah Package Calculator',style:TextStyle(fontSize:11))]),actions:[IconButton(tooltip:s['retry'],onPressed:store.busy?null:store.refresh,icon:const Icon(Icons.sync))]),body:Column(children:[if(store.busy)const LinearProgressIndicator(minHeight:2),if(store.cloudConflict)MaterialBanner(content:const Text('Cloud draft conflict. Select which draft to retain.'),actions:[TextButton(onPressed:()=>store.resolveConflict(false),child:const Text('Cloud')),TextButton(onPressed:()=>store.resolveConflict(true),child:const Text('This device'))]),Expanded(child:IndexedStack(index:index,children:[CalculatorScreen(store),HotelsScreen(store),ArchiveScreen(store),SettingsScreen(store)]))]),bottomNavigationBar:BottomNavigationBar(type:BottomNavigationBarType.fixed,currentIndex:index,onTap:(v)=>setState(()=>index=v),selectedItemColor:const Color(0xff006abd),items:[BottomNavigationBarItem(icon:const Icon(Icons.calculate_outlined),label:s['calculator']),BottomNavigationBarItem(icon:const Icon(Icons.apartment),label:s['hotels']),BottomNavigationBarItem(icon:const Icon(Icons.inventory_2_outlined),label:s['archive']),BottomNavigationBarItem(icon:const Icon(Icons.settings_outlined),label:s['settings'])]));
  }
}
Future<bool> askConfirm(BuildContext context,String text)async=>await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(content:Text(text),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(Strings.of(context)['cancel'])),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(Strings.of(context)['confirm']))]))??false;
Future<void> runAction(BuildContext context,Future<void> Function() action)async {
  try{await action();}catch(e){if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()),duration:const Duration(seconds:7)));}}
}
