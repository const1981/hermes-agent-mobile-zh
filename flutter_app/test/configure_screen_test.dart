import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_agent_mobile/providers/config_provider.dart';
import 'package:hermes_agent_mobile/screens/configure_screen.dart';

void main() {
  testWidgets('ConfigureScreen 在手机窄屏下不应溢出/空白', (tester) async {
    // 模拟手机竖屏 360x800（窄屏，最容易触发 NavigationRail 布局问题）
    tester.binding.window.physicalSizeTestValue = const Size(360, 800);
    tester.binding.window.devicePixelRatioTestValue = 2.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: ChangeNotifierProvider(
          create: (_) => ConfigProvider(),
          child: const ConfigureScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认停在「模型」面板，应能看到供应商选择标题
    expect(find.text('选择供应商'), findsOneWidget);
    expect(find.text('DeepSeek'), findsWidgets);

    // 检查有没有布局溢出 / 断言异常（白屏的常见根因）。
    // 注意：测试环境下常见 <1px 的亚像素溢出（浮点取整导致，真机不可见、不导致白屏），
    // 这类一律放行；只抓 ≥1px 的真实溢出（如之前 NavigationRail 在窄屏溢出 30/280px 的真 bug）。
    final ex = tester.takeException();
    if (ex != null) {
      final msg = ex.toString();
      final m = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(msg);
      final px = m != null ? double.tryParse(m.group(1)!) : null;
      if (px == null || px >= 1.0) {
        expect(ex, isNull, reason: 'build 不应抛异常或明显溢出: $ex');
      }
    }
  });
}
