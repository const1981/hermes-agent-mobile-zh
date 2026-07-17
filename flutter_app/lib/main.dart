import 'package:flutter/material.dart';
import 'app.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 读取真实 APK 版本号，避免界面显示与真实包版本脱节（v0.3.48 修复）。
  await AppConstants.initRealVersion();
  // 任何 widget build 抛异常时显示可见错误文本（红底），而不是静默白屏，
  // 避免再次出现「页面空白但找不到原因」的情况。
  ErrorWidget.builder = (details) {
    final stack = (details.stack?.toString().split('\n') ?? [])
        .where((l) => l.contains('.dart') || l.contains('package:'))
        .take(6)
        .join('\n');
    return Material(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('页面渲染出错',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(),
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('调用栈（请将此页截图发我即可定位）：',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(stack, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const HermesAgentApp());
}
