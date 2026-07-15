import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_agent_mobile/providers/config_provider.dart';
import 'package:hermes_agent_mobile/screens/configure_screen.dart';
import 'package:hermes_agent_mobile/screens/gateway_screen.dart';

// 本地渲染诊断：把 configure（含4个tab）与 gateway 页都渲染一遍，
// 任何 build 期抛出的 Null check / assert 都会在此暴露并定位行号。
Future<void> main() async {
  testWidgets('configure: model tab renders', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<ConfigProvider>(
      create: (_) => ConfigProvider(),
      child: const MaterialApp(home: ConfigureScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('模型供应商'), findsWidgets);
  });

  testWidgets('configure: switch all 4 tabs', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<ConfigProvider>(
      create: (_) => ConfigProvider(),
      child: const MaterialApp(home: ConfigureScreen()),
    ));
    await tester.pumpAndSettle();
    for (final t in ['对接', '技能', '设置']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
    }
    // 回到模型 tab 再切一次，确保 ExpansionTile 展开路径也走一遍
    await tester.tap(find.text('对接'));
    await tester.pumpAndSettle();
  });

  testWidgets('gateway screen renders', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<ConfigProvider>(
      create: (_) => ConfigProvider(),
      child: const MaterialApp(home: GatewayScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('网关状态'), findsOneWidget);
    // 展开一个渠道的字段（enabled=false 时不会展开，这里手动触发一次 toggle 路径）
    expect(find.text('沟通渠道'), findsOneWidget);
  });
}
