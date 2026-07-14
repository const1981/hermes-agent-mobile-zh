import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 任何 widget build 抛异常时显示可见错误文本（红底），而不是静默白屏，
  // 避免再次出现「页面空白但找不到原因」的情况。
  ErrorWidget.builder = (details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            '页面渲染出错：\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      ),
    );
  };
  runApp(const HermesAgentApp());
}
