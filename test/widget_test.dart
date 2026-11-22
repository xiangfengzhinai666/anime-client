import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anime_client/main.dart';

void main() {
  testWidgets('S0 自检窗口能正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(const SelfCheckApp());

    expect(find.text('anime_client'), findsOneWidget);
    expect(find.text('环境自检 · S0'), findsOneWidget);
    expect(find.text('S0 · 环境自检通过'), findsOneWidget);
    expect(find.text('渲染探针'), findsOneWidget);
    expect(find.text('交互探针'), findsOneWidget);
  });

  testWidgets('交互探针可以触发 SnackBar', (WidgetTester tester) async {
    await tester.pumpWidget(const SelfCheckApp());

    final button = find.text('触发一次交互');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('输入框可输入文字', (WidgetTester tester) async {
    await tester.pumpWidget(const SelfCheckApp());

    await tester.enterText(find.byType(TextField), '芙莉莲');
    await tester.pump();

    expect(find.text('芙莉莲'), findsOneWidget);
  });
}
