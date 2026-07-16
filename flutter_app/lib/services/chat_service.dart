import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/chat_message.dart';

/// 与主 Agent（本地网关 127.0.0.1:18789）的 OpenAI 兼容对话服务。
///
/// 网关暴露标准 OpenAI 路由：<gatewayUrl>/v1/chat/completions，
/// 鉴权头 `Authorization: Bearer <模型 Key>`（与配置页测 /models 一致）。
class ChatService {
  /// 流式发送一轮对话。
  ///
  /// [history] 完整对话历史（不含本方法内部追加的占位），每条 {role, content}。
  /// [onDelta] 每收到一段增量文本即回调（用于逐字渲染）。
  /// [onDone] 一轮结束回调：full=完整文本，error 非空表示失败。
  /// [onStatus] 连接状态提示（如 "正在连接网关..." / "" 表示已连上）。
  ///
  /// 返回取消函数：调用即可中断当前请求（用于"停止"按钮）。
  void Function() streamChat({
    required List<ChatMessage> history,
    required String model,
    required String apiKey,
    void Function(String delta)? onDelta,
    void Function(String full, String? error)? onDone,
    void Function(String status)? onStatus,
  }) {
    final client = http.Client();
    var cancelled = false;
    var full = '';

    final uri = Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': history.map((m) => m.toApi()).toList(),
      'stream': true,
    });

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = body;

    onStatus?.call('正在连接网关...');

    // 异步执行流式读取；cancel 通过关闭 client 中断底层连接。
    _readStream(client, request, (delta) {
      full += delta;
      onDelta?.call(delta);
    }, (rawJsonOrNull) {
      // rawJsonOrNull 非 null 表示网关返回了单条 JSON（未走 SSE）
      if (rawJsonOrNull != null && full.isEmpty) {
        try {
          final json = jsonDecode(rawJsonOrNull) as Map<String, dynamic>;
          final choices = json['choices'];
          if (choices != null && choices.isNotEmpty) {
            final msg = choices[0]['message'] ?? {};
            final content = msg['content'];
            if (content is String && content.isNotEmpty) {
              full = content;
              onDelta?.call(content);
            }
          }
        } catch (_) {
          // 忽略无法解析的兜底内容
        }
      }
      if (cancelled) {
        onDone?.call(full, null);
      } else {
        onDone?.call(full, null);
      }
    }, (error) {
      if (cancelled) {
        onDone?.call(full, null);
      } else {
        onDone?.call(full, error);
      }
    }, () => onStatus?.call(''));

    return () {
      cancelled = true;
      client.close();
    };
  }

  Future<void> _readStream(
    http.Client client,
    http.Request request,
    void Function(String delta) onDelta,
    void Function(String? rawJson) onCompleted,
    void Function(String error) onError,
    void Function() onConnected,
  ) async {
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        onError('网关返回 ${response.statusCode}：$errBody');
        return;
      }
      onConnected();

      var rawBuffer = '';
      var sawDataLine = false;

      await for (final line
          in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (line.startsWith('data:')) {
          sawDataLine = true;
          final data = line.substring(5).trim();
          if (data == '[DONE]') break;
          _parseSseData(data, onDelta);
        } else if (line.trim().startsWith('{')) {
          // 网关未走 SSE，整段是单个 JSON
          rawBuffer = line;
        }
      }

      // 若全程没见到 data: 行，把收集到的原始 JSON 当作单条响应兜底
      onCompleted(sawDataLine ? null : rawBuffer);
    } catch (e) {
      // 用户主动取消会触发 client 关闭导致的异常，这里统一交给上层判断
      onError('网络错误：$e');
    }
  }

  void _parseSseData(String data, void Function(String delta) onDelta) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'];
      if (choices == null || choices.isEmpty) return;
      final delta = choices[0]['delta'] ?? {};
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        onDelta(content);
      }
    } catch (_) {
      // 跳过无法解析的心跳/注释行
    }
  }
}
