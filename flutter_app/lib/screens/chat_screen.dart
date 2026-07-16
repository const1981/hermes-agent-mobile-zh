import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../providers/config_provider.dart';
import '../providers/gateway_provider.dart';

/// 微信风「与 AI 主 Agent 对话」界面。
/// 替换原「对话终端」入口：不走终端，直接打本地网关的 OpenAI 兼容接口，
/// 流式逐字返回，多轮上下文保留。
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  bool _busy = false;
  String _status = '';
  VoidCallback? _cancelFn;

  @override
  void initState() {
    super.initState();
    // 进入时刷新配置（模型 Key / 默认模型），与配置页同逻辑。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cfg = context.read<ConfigProvider>();
      await cfg.loadEnv();
      await cfg.loadModelConfig();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _cancelFn?.call();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;

    final cfg = context.read<ConfigProvider>();
    if (cfg.apiKey.isEmpty) {
      _showSnack('请先在「配置」页填写模型 Key 并保存');
      return;
    }
    final gw = context.read<GatewayProvider>();
    if (!gw.isRunning) {
      _showSnack('网关未启动，请先点上方「启动网关」');
      return;
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messages.add(ChatMessage(role: 'assistant', content: '', isStreaming: true));
      _busy = true;
      _status = '';
      _inputController.clear();
    });
    _scrollToBottom();

    // 发给网关的历史 = 除最后一条占位外的全部消息
    final history = _messages.sublist(0, _messages.length - 1);

    _cancelFn = _chatService.streamChat(
      history: history,
      model: cfg.model,
      apiKey: cfg.apiKey,
      onStatus: (s) => setState(() => _status = s),
      onDelta: (delta) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = last.copyWith(content: last.content + delta);
        });
        _scrollToBottom();
      },
      onDone: (full, err) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = last.copyWith(
            content: err != null ? (full.isEmpty ? err : full) : full,
            isStreaming: false,
            isError: err != null,
          );
          _busy = false;
          _status = '';
        });
        _cancelFn = null;
        _scrollToBottom();
      },
    );
  }

  void _stop() {
    _cancelFn?.call();
    _cancelFn = null;
    if (mounted) {
      setState(() {
        final last = _messages.last;
        if (last.isStreaming) {
          _messages[_messages.length - 1] = last.copyWith(isStreaming: false);
        }
        _busy = false;
        _status = '';
      });
    }
  }

  void _clear() {
    if (_busy) return;
    setState(() => _messages.clear());
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        elevation: 0.5,
        shadowColor: Colors.black12,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('对话'),
            if (cfg.model.isNotEmpty)
              Text(
                cfg.model,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF999999),
                ),
              ),
          ],
        ),
        actions: [
          if (_busy)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              tooltip: '停止生成',
              onPressed: _stop,
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空对话',
              onPressed: _clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Consumer<GatewayProvider>(
            builder: (context, gw, _) {
              if (gw.isRunning) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '网关未启动，无法对话',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.orange.shade800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => gw.start(),
                      child: const Text('启动网关'),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyHint(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _buildBubble(_messages[i], theme),
                  ),
          ),
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  _status,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: Colors.black.withOpacity(0.15)),
          const SizedBox(height: 12),
          Text(
            '和 AI 主 Agent 聊点什么吧',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF999999)),
          ),
          const SizedBox(height: 4),
          Text(
            '支持多轮上下文，回复流式逐字显示',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFB3B3B3)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, ThemeData theme) {
    final isUser = msg.role == 'user';
    const avatarRadius = 19.0;
    final avatar = CircleAvatar(
      radius: avatarRadius,
      backgroundColor: isUser ? const Color(0xFF7B68EE) : Colors.green,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 20,
        color: Colors.white,
      ),
    );

    Widget bubble;
    if (msg.isStreaming && msg.content.isEmpty) {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('思考中…', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    } else {
      bubble = Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: isUser
              ? const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: SelectableText(
          msg.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: msg.isError ? Colors.red : const Color(0xFF111111),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isUser
            ? [bubble, const SizedBox(width: 10), avatar]
            : [avatar, const SizedBox(width: 10), bubble],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF7F7F7F)),
              onPressed: () => _showSnack('语音输入暂未开放'),
              tooltip: '语音',
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: _busy ? '生成中…' : '发消息…',
                    hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied, color: Color(0xFF7F7F7F)),
              onPressed: () => _showSnack('表情面板暂未开放'),
              tooltip: '表情',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7F7F7F)),
              onPressed: () => _showSnack('更多功能暂未开放'),
              tooltip: '更多',
            ),
          ],
        ),
      ),
    );
  }
}
