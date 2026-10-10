import 'package:flutter/material.dart';
const navy=Color(0xff001d34), green=Color(0xff126b3d), blue=Color(0xff006abd), gold=Color(0xffbd9417);
ThemeData upcTheme(bool dark) => ThemeData(
  useMaterial3:false,
  brightness:dark?Brightness.dark:Brightness.light,
  scaffoldBackgroundColor:dark?const Color(0xff101e29):const Color(0xfff5f8fa),
  primaryColor:blue,
  colorScheme:ColorScheme.fromSeed(seedColor:blue,brightness:dark?Brightness.dark:Brightness.light),
  appBarTheme:const AppBarTheme(backgroundColor:navy,foregroundColor:Colors.white,elevation:0,centerTitle:true),
  inputDecorationTheme:InputDecorationTheme(isDense:true,filled:true,fillColor:dark?const Color(0xff213341):const Color(0xfff1f4f7),contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:12),border:OutlineInputBorder(borderRadius:BorderRadius.circular(7),borderSide:const BorderSide(color:Color(0xffdce3e9))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(7),borderSide:const BorderSide(color:Color(0xffdce3e9)))),
  elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(backgroundColor:blue,foregroundColor:Colors.white,minimumSize:const Size(48,44),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),elevation:0)),
  textTheme:const TextTheme(bodyMedium:TextStyle(fontSize:14),bodySmall:TextStyle(fontSize:12),titleMedium:TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
);
class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key,required this.child});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).dividerColor.withValues(alpha:.12))),child:child);
}
class Counter extends StatelessWidget {
  final int value;final ValueChanged<int> onChanged;
  const Counter({super.key,required this.value,required this.onChanged});
  @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'−',constraints:const BoxConstraints(minWidth:44,minHeight:44),padding:EdgeInsets.zero,onPressed:value>0?()=>onChanged(value-1):null,icon:const Icon(Icons.remove,size:18)),SizedBox(width:38,child:Text('$value',textAlign:TextAlign.center)),IconButton(tooltip:'+',constraints:const BoxConstraints(minWidth:44,minHeight:44),padding:EdgeInsets.zero,onPressed:()=>onChanged(value+1),icon:const Icon(Icons.add,size:18))]);
}
