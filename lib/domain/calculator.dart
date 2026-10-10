import 'dart:convert';

enum CalcMode { group, individual }
enum RatePlan { roomOnly, bb, hb, fb }
enum RoomType { dbl, trpl, quad }
enum ServiceType { fixed, perPerson, quantity }

String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDay(String s) { final d = DateTime.parse(s); return DateTime.utc(d.year, d.month, d.day); }
int cents(String text) {
  final s = text.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(s)) { throw const FormatException('Use a nonnegative amount with at most two decimals.'); }
  final parts = s.split('.');
  return int.parse(parts[0]) * 100 + (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
String money(int c) => '${c < 0 ? '-' : ''}${c.abs() ~/ 100}.${(c.abs() % 100).toString().padLeft(2, '0')}';
String planLabel(RatePlan p) => ['Room Only','BB','HB','FB'][p.index];
String roomLabel(RoomType t) => ['DBL','TRPL','QUAD'][t.index];
int beds(RoomType t) => [2,3,4][t.index];
String rateKey(CalcMode mode, RoomType type, RatePlan plan) => '${mode == CalcMode.group ? 'GROUP' : roomLabel(type)}/${plan.name}';

class Period {
  final String id, from, to;
  final Map<String,int> rates;
  Period(this.id, this.from, this.to, this.rates) {
    if (parseDay(to).isBefore(parseDay(from))) { throw ArgumentError('End before start'); }
    if (rates.values.any((x) => x < 0)) { throw ArgumentError('Negative rate'); }
  }
  bool contains(String date) => date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
  bool overlaps(Period other) => from.compareTo(other.to) <= 0 && to.compareTo(other.from) >= 0;
  Map<String,dynamic> toJson() => {'id':id,'from_date':from,'to_date':to,'rates':rates};
  factory Period.fromJson(Map<String,dynamic> j) => Period(j['id'] as String,j['from_date'] as String,j['to_date'] as String,Map<String,int>.from(j['rates'] as Map));
}
class Hotel {
  String id, name, city;
  List<Period> periods;
  Hotel(this.id,this.name,this.city,[List<Period>? periods]):periods=periods??[];
  int? price(String date,String key) {
    final found=periods.where((p)=>p.contains(date)).toList();
    if(found.length>1) { throw StateError('Price period overlap. Enter new date & price.'); }
    return found.isEmpty ? null : found.single.rates[key];
  }
  void addPeriod(Period p) {
    if(periods.any((x)=>x.id!=p.id && x.overlaps(p))) { throw StateError('Price period overlap. Enter new date & price.'); }
    periods.removeWhere((x)=>x.id==p.id);periods.add(p);
  }
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'city':city,'periods':periods.map((p)=>p.toJson()).toList()};
  factory Hotel.fromJson(Map<String,dynamic> j)=>Hotel(j['id'] as String,j['name'] as String,j['city'] as String,(j['periods'] as List? ?? []).map((p)=>Period.fromJson(Map<String,dynamic>.from(p as Map))).toList());
}
class NightOverride {
  RatePlan plan;
  int price;
  NightOverride(this.plan,this.price);
  Map<String,dynamic> toJson()=>{'plan':plan.name,'price':price};
  factory NightOverride.fromJson(Map<String,dynamic> j)=>NightOverride(RatePlan.values.byName(j['plan'] as String),j['price'] as int);
}
class RoomLine {
  String id;
  RoomType type;
  int quantity;
  RatePlan plan;
  int? manualPrice;
  Map<String,NightOverride> overrides;
  RoomLine(this.id,{this.type=RoomType.dbl,this.quantity=0,this.plan=RatePlan.roomOnly,this.manualPrice,Map<String,NightOverride>? overrides}):overrides=overrides??{};
  Map<String,dynamic> toJson()=>{'id':id,'type':type.name,'quantity':quantity,'plan':plan.name,'manualPrice':manualPrice,'overrides':overrides.map((k,v)=>MapEntry(k,v.toJson()))};
  factory RoomLine.fromJson(Map<String,dynamic> j)=>RoomLine(j['id'] as String,type:RoomType.values.byName(j['type'] as String),quantity:j['quantity'] as int,plan:RatePlan.values.byName(j['plan'] as String),manualPrice:j['manualPrice'] as int?,overrides:(j['overrides'] as Map? ?? {}).map((k,v)=>MapEntry(k.toString(),NightOverride.fromJson(Map<String,dynamic>.from(v as Map)))));
}
class Stay {
  String city, hotelName;
  String? hotelId;
  bool enabled;
  String checkIn,checkOut;
  int totalPax;
  RoomLine group;
  List<RoomLine> individual;
  Stay(this.city,{this.enabled=true,this.hotelId,this.hotelName='',required this.checkIn,required this.checkOut,this.totalPax=0,required this.group,List<RoomLine>? individual}):individual=individual??[];
  List<String> get nights {
    final from=parseDay(checkIn), to=parseDay(checkOut);
    if(!to.isAfter(from)) { throw ArgumentError('Check-out must be later than check-in.'); }
    if(to.difference(from).inDays>730) { throw ArgumentError('Maximum stay is 730 nights.'); }
    return List.generate(to.difference(from).inDays,(i)=>day(from.add(Duration(days:i))));
  }
  int get actualGuests=>individual.fold(0,(sum,line)=>sum+line.quantity*beds(line.type));
  List<RoomLine> lines(CalcMode m)=>m==CalcMode.group?[group]:individual;
  Map<String,dynamic> toJson()=>{'city':city,'enabled':enabled,'hotelId':hotelId,'hotelName':hotelName,'checkIn':checkIn,'checkOut':checkOut,'totalPax':totalPax,'group':group.toJson(),'individual':individual.map((x)=>x.toJson()).toList()};
  factory Stay.fromJson(Map<String,dynamic> j)=>Stay(j['city'] as String,enabled:j['enabled'] as bool,hotelId:j['hotelId'] as String?,hotelName:j['hotelName'] as String,checkIn:j['checkIn'] as String,checkOut:j['checkOut'] as String,totalPax:j['totalPax'] as int,group:RoomLine.fromJson(Map<String,dynamic>.from(j['group'] as Map)),individual:(j['individual'] as List).map((x)=>RoomLine.fromJson(Map<String,dynamic>.from(x as Map))).toList());
}
class ExtraService {
  String id,name;
  ServiceType type;
  int quantity,unitPrice;
  bool deduct;
  ExtraService(this.id,{this.name='',this.type=ServiceType.fixed,this.quantity=1,this.unitPrice=0,this.deduct=false});
  int get total {
    if(quantity<0||unitPrice<0) { throw ArgumentError('Negative service input'); }
    return unitPrice*(type==ServiceType.fixed?1:quantity)*(deduct?-1:1);
  }
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'type':type.name,'quantity':quantity,'unitPrice':unitPrice,'deduct':deduct};
  factory ExtraService.fromJson(Map<String,dynamic> j)=>ExtraService(j['id'] as String,name:j['name'] as String,type:ServiceType.values.byName(j['type'] as String),quantity:j['quantity'] as int,unitPrice:j['unitPrice'] as int,deduct:j['deduct'] as bool);
}
class Draft {
  String id,name;
  CalcMode mode;
  Stay madinah,makkah;
  List<ExtraService> services;
  double? fx;
  bool fxManual;
  Draft(this.id,{this.name='',this.mode=CalcMode.group,required this.madinah,required this.makkah,List<ExtraService>? services,this.fx,this.fxManual=false}):services=services??[];
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'mode':mode.name,'madinah':madinah.toJson(),'makkah':makkah.toJson(),'services':services.map((s)=>s.toJson()).toList(),'fx':fx,'fxManual':fxManual};
  factory Draft.fromJson(Map<String,dynamic> j)=>Draft(j['id'] as String,name:j['name'] as String,mode:CalcMode.values.byName(j['mode'] as String),madinah:Stay.fromJson(Map<String,dynamic>.from(j['madinah'] as Map)),makkah:Stay.fromJson(Map<String,dynamic>.from(j['makkah'] as Map)),services:(j['services'] as List).map((s)=>ExtraService.fromJson(Map<String,dynamic>.from(s as Map))).toList(),fx:(j['fx'] as num?)?.toDouble(),fxManual:j['fxManual'] as bool? ?? false);
  Draft copy()=>Draft.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String,dynamic>);
  bool get nonempty=>name.isNotEmpty||services.isNotEmpty||madinah.hotelName.isNotEmpty||makkah.hotelName.isNotEmpty||madinah.group.quantity>0||makkah.group.quantity>0||madinah.actualGuests>0||makkah.actualGuests>0;
}
class MissingPrice implements Exception {
  final List<String> dates;
  MissingPrice(this.dates);
  @override String toString()=>'Missing nightly prices: ${dates.join(', ')}';
}
class CityResult {
  final int total;
  final List<Map<String,dynamic>> nights;
  CityResult(this.total,this.nights);
  Map<String,dynamic> toJson()=>{'total':total,'nights':nights};
}
class PackageResult {
  final CityResult madinah,makkah;
  final int services;
  final double? fx;
  PackageResult(this.madinah,this.makkah,this.services,this.fx);
  int get total=>madinah.total+makkah.total+services;
  String? get usd=>fx==null?null:(total/100/fx!).toStringAsFixed(2);
  Map<String,dynamic> toJson()=>{'madinah':madinah.toJson(),'makkah':makkah.toJson(),'services':services,'total':total,'fx':fx,'usd':usd};
}
class Calculator {
  static CityResult city(Stay stay,CalcMode mode,List<Hotel> hotels) {
    if(!stay.enabled) { return CityResult(0,[]); }
    if(stay.totalPax<0) { throw ArgumentError('Negative guests'); }
    final dates=stay.nights;
    final matches=hotels.where((h)=>h.id==stay.hotelId&&h.city==stay.city);
    final hotel=matches.isEmpty?null:matches.first;
    final missing=<String>[], breakdown=<Map<String,dynamic>>[];
    var total=0;
    for(final line in stay.lines(mode)) {
      if(line.quantity<0) { throw ArgumentError('Negative room quantity'); }
      if(line.quantity==0) { continue; }
      for(final date in dates) {
        final override=line.overrides[date];
        final plan=override?.plan??line.plan;
        final rate=override?.price??line.manualPrice??hotel?.price(date,rateKey(mode,line.type,plan));
        if(rate==null) { missing.add('${stay.city} $date ${mode==CalcMode.group?'GROUP':roomLabel(line.type)} ${planLabel(plan)}'); continue; }
        if(rate<0) { throw ArgumentError('Negative room rate'); }
        final amount=line.quantity*rate;total+=amount;
        breakdown.add({'lineId':line.id,'date':date,'type':mode==CalcMode.group?'GROUP':roomLabel(line.type),'quantity':line.quantity,'plan':plan.name,'price':rate,'total':amount});
      }
    }
    if(missing.isNotEmpty) { throw MissingPrice(missing); }
    return CityResult(total,breakdown);
  }
  static PackageResult calculate(Draft d,List<Hotel> hotels) {
    if(d.fx!=null&&(!d.fx!.isFinite||d.fx!<=0)) { throw ArgumentError('Exchange rate must be positive'); }
    return PackageResult(city(d.madinah,d.mode,hotels),city(d.makkah,d.mode,hotels),d.services.fold(0,(sum,s)=>sum+s.total),d.fx);
  }
  static Map<String,dynamic> snapshot(Draft d,List<Hotel> hotels)=>{'schemaVersion':1,'draft':d.toJson(),'result':calculate(d,hotels).toJson()};
  static Draft duplicate(Map<String,dynamic> snapshot,String id) {
    final d=Draft.fromJson(Map<String,dynamic>.from(snapshot['draft'] as Map));d.id=id;
    final result=snapshot['result'] as Map;
    for(final stay in [d.madinah,d.makkah]) {
      final nights=(result[stay.city] as Map)['nights'] as List;
      for(final line in stay.lines(d.mode)) {
        for(final n in nights.where((n)=>n['lineId']==line.id)) {
          line.overrides[n['date'] as String]=NightOverride(RatePlan.values.byName(n['plan'] as String),n['price'] as int);
        }
      }
    }
    return d;
  }
}
