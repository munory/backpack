import 'package:backpack/common/app_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> tapWith(WidgetTester tester, {required bool value, bool partial = false}) async {
    bool? got;
    await tester.pumpWidget(MaterialApp(
      home: Center(child: AppCheckbox(value: value, partial: partial, onChanged: (v) => got = v)),
    ));
    await tester.tap(find.byType(AppCheckbox));
    return got;
  }

  testWidgets('empty → packs, full → unpacks', (tester) async {
    expect(await tapWith(tester, value: false), isTrue);
    expect(await tapWith(tester, value: true), isFalse);
  });

  testWidgets('a dash (some packed) packs the rest', (tester) async {
    expect(await tapWith(tester, value: false, partial: true), isTrue);
  });
}
