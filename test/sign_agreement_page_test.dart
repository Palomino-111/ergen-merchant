// 临时诊断用测试：渲染「协议签署页」（APP 首屏），打印布局与颜色信息，
// 用于确认「同意 / 不同意」按钮是否可见。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:zheergen_merchant_end/common/theme/app_theme.dart';
import 'package:zheergen_merchant_end/page/sign_agreement/view.dart';

void main() {
  setUpAll(() async {
    final Directory dir = Directory.systemTemp.createTempSync('zheergen_hive');
    Hive.init(dir.path);
    await Hive.openBox('settings');
  });

  testWidgets('协议签署页首屏渲染诊断', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final List<Object> exceptions = <Object>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      exceptions.add(details.exception);
      debugPrint('>>> FLUTTER ERROR: ${details.exception}');
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) => GetMaterialApp(
          theme: AppTheme.dark(context: context),
          darkTheme: AppTheme.dark(context: context),
          debugShowCheckedModeBanner: false,
          home: SignAgreementPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('===== 异常数量: ${exceptions.length}');
    debugPrint(
        '===== ErrorWidget 数量: ${find.byType(ErrorWidget).evaluate().length}');

    final ColorScheme scheme =
        Theme.of(tester.element(find.byType(SignAgreementPage))).colorScheme;
    debugPrint('===== colorScheme.secondary = ${scheme.secondary}');
    debugPrint('===== colorScheme.onSecondary = ${scheme.onSecondary}');
    debugPrint('===== colorScheme.surface = ${scheme.surface}');

    for (final String label in <String>['同意', '不同意', '用户协议', '隐私政策']) {
      final Finder finder = find.textContaining(label);
      final int count = finder.evaluate().length;
      debugPrint('===== 文本 "$label" 命中 $count 个');
      if (count == 0) {
        continue;
      }
      final Element element = tester.element(finder.first);
      debugPrint('    rect=${tester.getRect(finder.first)}');
      debugPrint('    有效文字样式=${DefaultTextStyle.of(element).style}');
      for (final Element e
          in find.ancestor(of: finder.first, matching: find.byType(DecoratedBox)).evaluate()) {
        final Decoration decoration = (e.widget as DecoratedBox).decoration;
        debugPrint(
            '    祖先 DecoratedBox: ${decoration is BoxDecoration ? decoration.color : decoration}');
      }
    }

    debugPrint('===== 底部区域命中测试');
    final Offset bottomCenter = Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      tester.view.physicalSize.height / tester.view.devicePixelRatio - 60,
    );
    debugPrint('    $bottomCenter -> ${tester.hitTestOnBinding(bottomCenter).path.take(4).map((HitTestEntry e) => e.target.runtimeType).toList()}');
  });
}
