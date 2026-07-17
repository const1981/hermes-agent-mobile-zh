enum GatewayStatus {
  stopped,
  starting,
  running,
  error,
}

class GatewayState {
  final GatewayStatus status;
  final List<String> logs;
  final String? errorMessage;
  final DateTime? startedAt;
  final String? dashboardUrl;
  /// v0.3.50：自动启动因「未配置模型 Key」被跳过时置 true，
  /// UI 据此提示用户先去配置页填 Key，而不是误以为在自动启动。
  final bool needsConfiguration;

  const GatewayState({
    this.status = GatewayStatus.stopped,
    this.logs = const [],
    this.errorMessage,
    this.startedAt,
    this.dashboardUrl,
    this.needsConfiguration = false,
  });

  GatewayState copyWith({
    GatewayStatus? status,
    List<String>? logs,
    String? errorMessage,
    bool clearError = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? dashboardUrl,
    bool clearDashboardUrl = false,
    bool? needsConfiguration,
  }) {
    return GatewayState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      dashboardUrl: clearDashboardUrl ? null : (dashboardUrl ?? this.dashboardUrl),
      needsConfiguration: needsConfiguration ?? this.needsConfiguration,
    );
  }

  bool get isRunning => status == GatewayStatus.running;
  bool get isStopped => status == GatewayStatus.stopped;

  String get statusText {
    switch (status) {
      case GatewayStatus.stopped:
        return '已停止';
      case GatewayStatus.starting:
        return '启动中...';
      case GatewayStatus.running:
        return '运行中';
      case GatewayStatus.error:
        return '错误';
    }
  }
}
