import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'data/store.dart';
import 'l10n/strings.dart';
import 'ui/auth.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs=await SharedPreferences.getInstance();
  if(Config.configured) { await Supabase.initialize(url:Config.supabaseUrl,anonKey:Config.supabaseKey); }
  runApp(UpcApp(prefs));
}
class UpcApp extends StatefulWidget {
  final SharedPreferences prefs;
  const UpcApp(this.prefs,{super.key});
  @override State<UpcApp> createState()=>_UpcAppState();
}
class _UpcAppState extends State<UpcApp> {
  UpcStore? store;
  StreamSubscription<AuthState>? authSubscription;
  @override void initState() {
    super.initState();
    if(Config.configured) {
      updateIdentity();
      authSubscription=Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        updateIdentity();
        if(mounted) { setState(() {}); }
      });
    }
  }
  void refreshView() { if(mounted) { setState(() {}); } }
  void updateIdentity() {
    final client=Supabase.instance.client,user=client.auth.currentUser;
    if(store?.userId==user?.id) { return; }
    store?.removeListener(refreshView);store?.dispose();store=null;
    if(user!=null) {
      store=UpcStore(client,widget.prefs);
      store!.addListener(refreshView);
      store!.load();
    }
  }
  @override void dispose() { authSubscription?.cancel();store?.removeListener(refreshView);store?.dispose();super.dispose(); }
  @override Widget build(BuildContext context) {
    final code=store?.settings['language'] as String? ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final locale=Strings.supported.any((l)=>l.languageCode==code)?Locale(code):const Locale('en');
    return MaterialApp(title:'UPC — Umrah Package Calculator',debugShowCheckedModeBanner:false,locale:locale,supportedLocales:Strings.supported,localizationsDelegates:GlobalMaterialLocalizations.delegates,theme:upcTheme(false),darkTheme:upcTheme(true),themeMode:store?.settings['appearance']=='dark'?ThemeMode.dark:store?.settings['appearance']=='light'?ThemeMode.light:ThemeMode.system,home:!Config.configured?Scaffold(appBar:AppBar(title:const Text('UPC')),body:const Padding(padding:EdgeInsets.all(24),child:Text('Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in GitHub repository variables, apply the migrations, then build again. Account access cannot be simulated.'))):store==null?const AuthScreen():Shell(store!));
  }
}
