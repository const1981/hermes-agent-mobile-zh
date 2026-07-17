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

  /// 持久化用：只存必要字段。isStreaming 不存（落盘时一律按已完成处理）。
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'isError': isError,
      };

  /// 从磁盘恢复：流式标记强制为 false（app 关闭时未完成的回复视为已结束）。
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        isError: json['isError'] as bool? ?? false,
        isStreaming: false,
      );
}
