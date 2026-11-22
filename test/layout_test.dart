import 'package:anime_client/core/storage/daos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// 布局回归：在多种窗口尺寸下把五个页面都点一遍，任何 overflow / 断言都算失败。
///
/// 这是 S1 之后每个阶段都应该跑的"体检"，用来兜住响应式布局的回归。
void main() {
  const sizes = <Size>[
    Size(420, 860), // 手机窄屏（底部导航）
    Size(800, 700), // 窄桌面（底部导航 + 紧凑 hero）
    Size(1000, 700), // 刚过断点（侧栏）
    Size(1400, 900), // 常规桌面
    Size(1920, 1080), // 大屏
  ];

  for (final size in sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('布局 $label：五个页面切换均无异常', (tester) async {
      final db = newMemoryDatabase();
      addTearDown(db.close);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await bootApp(tester, db);
      expect(tester.takeException(), isNull, reason: '$label 启动时异常');

      for (final tab in ['索引', '搜索', '追番', '我的', '首页']) {
        await tester.tap(find.text(tab).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: '$label 切到「$tab」时异常');
      }

      await shutdownApp(tester);
    });
  }

  testWidgets('主题从设置表恢复：重启后仍是浅色', (tester) async {
    final db = newMemoryDatabase();
    addTearDown(db.close);

    // 模拟"上次启动时选了浅色"
    await SettingsDao(db).set('theme_mode', 'light');

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await bootApp(tester, db);
    await tester.pump(const Duration(milliseconds: 300));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await shutdownApp(tester);
  });
}
