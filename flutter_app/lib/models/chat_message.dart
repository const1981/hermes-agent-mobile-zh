/// 单条聊天消息（微信风对话用）。
class ChatMessage {
  /// 'user' | 'assistant' | 'system'
  final String role;
  final String content;
  final bool isError;
  final bool isStreaming;

  ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? content,
    bool? isError,
    bool? isStreaming,
  }) =>
      ChatMessage(
        role: role,
        content: content ?? this.content,
        isError: isError ?? this.isError,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  Map<String, String> toApi() => {'role': role, 'content': content};
}
