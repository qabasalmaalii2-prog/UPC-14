import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upc/domain/calculator.dart';
import 'package:upc/ui/sharing.dart';
import 'package:upc/ui/theme.dart';
void main(){
 testWidgets('Archive/share snapshot at narrow Android widths has no rendering exceptions',(tester)async{
  final d=Draft('test',name:'Umrah calculation',madinah:Stay('madinah',hotelName:'Test hotel',checkIn:'2026-10-10',checkOut:'2026-10-11',group:RoomLine('a',quantity:2,manualPrice:30000)),makkah:Stay('makkah',enabled:false,checkIn:'2026-10-11',checkOut:'2026-10-12',group:RoomLine('b')),fx:3.75);
  final snapshot=Calculator.snapshot(d,[]);
  for(final width in [320.0,360.0,390.0,480.0]){
   tester.view.physicalSize=Size(width,800);tester.view.devicePixelRatio=1;
   await tester.pumpWidget(MaterialApp(theme:upcTheme(false),home:Scaffold(body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(10),child:SnapshotBody(snapshot))))));
   await tester.pumpAndSettle();expect(tester.takeException(),isNull,reason:'Width $width');
  }
  tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
 });
 test('Share timestamp is generated per share, owner text includes formulas',(){final d=Draft('x',madinah:Stay('madinah',enabled:false,checkIn:'2026-10-10',checkOut:'2026-10-11',group:RoomLine('a')),makkah:Stay('makkah',enabled:false,checkIn:'2026-10-10',checkOut:'2026-10-11',group:RoomLine('b')));final s=Calculator.snapshot(d,[]);expect(shareText(s,'first',''),isNot(shareText(s,'second','')));expect(shareText(s,'first',''),isNot(contains('https://upc.app')));});
}
