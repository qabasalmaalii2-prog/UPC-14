import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/calculator.dart';

class UpcStore extends ChangeNotifier {
  final SupabaseClient client;
  final SharedPreferences prefs;
  late Draft draft;
  late final String userId;
  bool _disposed=false;
  List<Hotel> hotels=[];
  List<Map<String,dynamic>> archive=[];
  Map<String,dynamic> account={},settings={},appSettings={};
  String? error;
  bool busy=false,needsContinue=false,cloudConflict=false;
  int revision=0;
  Timer? _timer;
  Future<void> _draftQueue=Future.value();
  bool _dirty=false;
  static const uuid=Uuid();
  UpcStore(this.client,this.prefs) { userId=client.auth.currentUser!.id;draft=fresh(); }
  String get uid=>userId;
  String get key=>'upc.$uid';
  bool get owner=>account['role']=='OWNER';
  String get language=>settings['language'] as String? ?? 'en';
  Draft fresh() {
    final now=DateTime.now(); final today=day(now);
    Stay stay(String city)=>Stay(city,checkIn:today,checkOut:day(now.add(const Duration(days:1))),group:RoomLine(uuid.v4()),individual:[RoomLine(uuid.v4())]);
    return Draft(uuid.v4(),madinah:stay('madinah'),makkah:stay('makkah'),fx:settings['fx_manual']==true?(settings['fx_rate'] as num?)?.toDouble():null,fxManual:settings['fx_manual']==true);
  }
  Future<void> load() async {
    final cached=prefs.getString(key);
    if(cached!=null) {
      final j=jsonDecode(cached) as Map<String,dynamic>;
      draft=Draft.fromJson(Map<String,dynamic>.from(j['draft'] as Map));
      hotels=(j['hotels'] as List).map((h)=>Hotel.fromJson(Map<String,dynamic>.from(h as Map))).toList();
      archive=(j['archive'] as List).map((a)=>Map<String,dynamic>.from(a as Map)).toList();
      settings=Map<String,dynamic>.from(j['settings'] as Map? ?? {});
      revision=j['revision'] as int? ?? 0;_dirty=j['dirty'] as bool? ?? false;
    }
    needsContinue=draft.nonempty;
    await refresh();
    if(draft.fx==null&&!draft.fxManual){await autoFx();}
  }
  Future<void> cache() async {
    await prefs.setString(key,jsonEncode({'draft':draft.toJson(),'hotels':hotels.map((h)=>h.toJson()).toList(),'archive':archive,'settings':settings,'revision':revision,'dirty':_dirty}));
  }
  void changed() {
    _dirty=true;
    error=null;notifyListeners();
    _timer?.cancel();
    _timer=Timer(const Duration(milliseconds:450),()=>persistDraft());
  }
  Future<void> persistDraft() async {
    await cache();
    final captured=draft.toJson();
    _draftQueue=_draftQueue.then((_) async {
      if(cloudConflict) { return; }
      try {
        final v=await client.rpc('put_draft',params:{'p_body':captured,'p_expected':revision});
        revision=(v as num).toInt();
        if(jsonEncode(draft.toJson())==jsonEncode(captured)) { _dirty=false; }
        await cache();
      } catch(e) { error=e.toString();if(error!.contains('DRAFT_CONFLICT')) { cloudConflict=true; } }
      notifyListeners();
    });
    await _draftQueue;
  }
  Future<void> refresh() async {
    busy=true;notifyListeners();
    try {
      account=Map<String,dynamic>.from(await client.from('accounts').select().eq('id',uid).single());
      final config=await client.from('app_settings').select().eq('id',1).maybeSingle();
      appSettings=Map<String,dynamic>.from(config?['body'] as Map? ?? {});
      final rows=await client.from('hotels').select('*, price_periods(*)').eq('user_id',uid).order('name');
      hotels=rows.map((j)=>Hotel(j['id'] as String,j['name'] as String,j['city'] as String,(j['price_periods'] as List).map((p)=>Period.fromJson(Map<String,dynamic>.from(p as Map))).toList())).toList();
      final a=await client.from('archive').select().eq('user_id',uid).order('saved_at',ascending:false);
      archive=a.map((j)=>Map<String,dynamic>.from(j)).toList();
      final cloud=await client.from('drafts').select().eq('user_id',uid).maybeSingle();
      if(cloud!=null) {
        final cloudRevision=cloud['revision'] as int;
        if(_dirty&&cloudRevision!=revision) { cloudConflict=true;error='DRAFT_CONFLICT'; }
        else if(!_dirty) { draft=Draft.fromJson(Map<String,dynamic>.from(cloud['body'] as Map));revision=cloudRevision;needsContinue=draft.nonempty; }
      }
      final pref=await client.from('preferences').select().eq('user_id',uid).maybeSingle();
      if(pref!=null) { settings=Map<String,dynamic>.from(pref['body'] as Map); }
      await cache();
      if(_dirty&&!cloudConflict) { await persistDraft(); }
    } catch(e) { error=e.toString(); }
    busy=false;notifyListeners();
  }
  Future<void> resolveConflict(bool keepLocal) async {
    final cloud=await client.from('drafts').select().eq('user_id',uid).single();
    revision=cloud['revision'] as int;cloudConflict=false;
    if(!keepLocal) { draft=Draft.fromJson(Map<String,dynamic>.from(cloud['body'] as Map));_dirty=false;await cache(); }
    else { await persistDraft(); }
    notifyListeners();
  }
  Future<void> newDraft() async { draft=fresh();needsContinue=false;changed();await persistDraft();if(!draft.fxManual){await autoFx();} }
  void setMode(CalcMode mode) { if(mode==draft.mode) { return; }draft.mode=mode;draft.id=uuid.v4();changed(); }
  Future<void> putHotel(Hotel h) async {
    await client.from('hotels').upsert({'id':h.id,'user_id':uid,'name':h.name,'city':h.city});await refresh();
  }
  Future<void> deleteHotel(Hotel h) async { await client.from('hotels').delete().eq('id',h.id);await refresh(); }
  Future<void> putPeriod(Hotel h,Period p) async {
    if(h.periods.any((x)=>x.id!=p.id&&x.overlaps(p))) { throw StateError('Price period overlap. Enter new date & price.'); }
    await client.from('price_periods').upsert({...p.toJson(),'hotel_id':h.id,'user_id':uid});await refresh();
  }
  Future<void> deletePeriod(Period p) async { await client.from('price_periods').delete().eq('id',p.id);await refresh(); }
  Future<Map<String,dynamic>> submit(String action) async {
    if(cloudConflict) { throw StateError('Resolve the cloud draft conflict first.'); }
    final snapshot=Calculator.snapshot(draft,hotels);
    await client.rpc('submit_calculation',params:{'p_snapshot':snapshot,'p_action':action});
    if(action=='save') { await newDraft();await refresh(); }
    return snapshot;
  }
  Future<void> duplicate(Map<String,dynamic> entry) async {
    draft=Calculator.duplicate(Map<String,dynamic>.from(entry['snapshot'] as Map),uuid.v4());needsContinue=false;changed();await persistDraft();
  }
  Future<void> deleteArchive(String id) async { await client.from('archive').delete().eq('id',id);await refresh(); }
  Future<void> setSetting(String name,dynamic value) async {
    settings[name]=value;await cache();notifyListeners();
    await client.from('preferences').upsert({'user_id':uid,'body':settings});
  }
  Future<void> manualFx(double rate) async {
    if(!rate.isFinite||rate<=0){throw ArgumentError('Invalid rate');}
    draft.fx=rate;draft.fxManual=true;changed();
    settings['fx_manual']=true;settings['fx_rate']=rate;await cache();
    await client.from('preferences').upsert({'user_id':uid,'body':settings});
  }
  Future<void> resetFx() async {
    draft.fxManual=false;settings['fx_manual']=false;settings.remove('fx_rate');await cache();
    await autoFx();
    await client.from('preferences').upsert({'user_id':uid,'body':settings});
  }
  Future<void> autoFx() async {
    if(draft.fxManual) { return; }
    try {
      final response=await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds:12));
      if(response.statusCode!=200) { throw StateError('FX HTTP ${response.statusCode}'); }
      final j=jsonDecode(response.body) as Map<String,dynamic>;
      if(j['result']!='success') { throw StateError('FX unavailable'); }
      final rate=(j['rates']['SAR'] as num).toDouble();
      if(!rate.isFinite||rate<=0) { throw StateError('FX unavailable'); }
      await prefs.setString('$key.fx',jsonEncode({'rate':rate,'cachedAt':DateTime.now().toUtc().toIso8601String(),'source':'open.er-api.com'}));
      draft.fx=rate;changed();
    } catch(_) {
      final c=prefs.getString('$key.fx');draft.fx=null;
      if(c!=null) {
        final j=jsonDecode(c) as Map<String,dynamic>;
        if(DateTime.now().toUtc().difference(DateTime.parse(j['cachedAt'] as String)).inHours<24) { draft.fx=(j['rate'] as num).toDouble(); }
      }
      changed();
    }
  }
  @override void notifyListeners() { if(!_disposed){super.notifyListeners();} }
  @override void dispose() { _disposed=true;_timer?.cancel();super.dispose(); }
}
