import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../l10n/strings.dart';
import 'theme.dart';
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState()=>_AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email=TextEditingController(),password=TextEditingController(),fullName=TextEditingController(),confirm=TextEditingController();
  bool signup=false,busy=false;String? message;
  @override void dispose(){email.dispose();password.dispose();fullName.dispose();confirm.dispose();super.dispose();}
  Future<void> action(Future<void> Function() fn) async {
    setState(()=>busy=true);
    try{await fn();}catch(e){if(mounted){setState(()=>message=e.toString());}}
    finally{if(mounted){setState(()=>busy=false);}}
  }
  @override Widget build(BuildContext context) {
    final s=Strings.of(context),auth=Supabase.instance.client.auth;
    return Scaffold(backgroundColor:navy,body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(children:[const Text('UPC',style:TextStyle(color:Colors.white,fontSize:42,fontWeight:FontWeight.w800)),const Text('Umrah Package Calculator',style:TextStyle(color:Colors.white70)),const SizedBox(height:28),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(s['welcome'],style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),OutlinedButton.icon(icon:const Icon(Icons.login),label:Text(s['google']),onPressed:busy?null:()=>action(()=>auth.signInWithOAuth(OAuthProvider.google,redirectTo:Config.redirect).then((_){ }))),const Divider(),if(signup)...[TextField(controller:fullName,decoration:InputDecoration(labelText:s['fullName'])),const SizedBox(height:10)],TextField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],decoration:InputDecoration(labelText:s['email'])),const SizedBox(height:10),TextField(controller:password,obscureText:true,decoration:InputDecoration(labelText:s['password'])),if(signup)...[const SizedBox(height:10),TextField(controller:confirm,obscureText:true,decoration:InputDecoration(labelText:s['confirmPassword']))],const SizedBox(height:12),if(message!=null)Text(message!,style:const TextStyle(color:Colors.red)),ElevatedButton(onPressed:busy?null:()=>action(()async {
      if(signup){if(fullName.text.trim().isEmpty||password.text!=confirm.text){throw StateError('Check name and password confirmation.');}await auth.signUp(email:email.text.trim(),password:password.text,data:{'full_name':fullName.text.trim()},emailRedirectTo:Config.redirect);if(mounted){setState(()=>message='Check your email to confirm your account.');}}
      else{await auth.signInWithPassword(email:email.text.trim(),password:password.text);}
    }),child:Text(busy?'…':s[signup?'signUp':'signIn'])),TextButton(onPressed:busy?null:()=>setState(()=>signup=!signup),child:Text(s[signup?'signIn':'signUp'])),TextButton(onPressed:busy?null:()=>action(()async{await auth.resetPasswordForEmail(email.text.trim(),redirectTo:Config.redirect);if(mounted){setState(()=>message='Password reset email sent. Open it, then change your password in Settings.');}}),child:Text(s['forgot']))]))]))))));
  }
}
