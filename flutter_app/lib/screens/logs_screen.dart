import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../l10n/app_strings.dart';
import '../providers/gateway_provider.dart';
import '../services/install_log.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  String _filter = '';

  /// 安装日志内容（从 InstallLog 文件异步加载，只读一次）
  List<String> _installLines = [];
  bool _installLoaded = false;

  AppStrings get s => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _loadInstallLog();
  }

  Future<void> _loadInstallLog() async {
    try {
      final text = await InstallLog.readAll();
      if (text.trim().isNotEmpty) {
        setState(() {
          _installLines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
          _installLoaded = true;
        });
      } else {
        setState(() => _installLoaded = true);
      }
    } catch (_) {
      setState(() => _installLoaded = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 合并日志：安装日志在前 + 分隔线 + Gateway 运行时日志在后
  List<String> _mergedLogs(List<String> gatewayLogs) {
    if (_installLines.isEmpty && gatewayLogs.isEmpty) return [];
    if (_installLines.isEmpty) return gatewayLogs;
    if (gatewayLogs.isEmpty) return _installLines;
    return [..._installLines, '─── Gateway 运行时日志 ───', ...gatewayLogs];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.gatewayLogs),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top,
            ),
            tooltip: _autoScroll ? s.autoScrollOn : s.autoScrollOff,
            onPressed: () => setState(() => !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: s.copyAll,
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () async {
              setState(() { _installLoaded = false; _installLines = []; });
              await _loadInstallLog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.filterLogsPlaceholder,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _filter = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: Consumer<GatewayProvider>(
              builder: (context, provider, _) {
                // 加载中
                if (!_installLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allLogs = _mergedLogs(provider.logs);
                final filtered = _filter.isEmpty
                    ? allLogs
                    : allLogs.where((l) => l.toLowerCase().contains(_filter)).toList();

                // 完全空——显示醒目空状态
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 48, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text(s.noLogsYet, style: TextStyle(color: theme.disabledColor)),
                        const SizedBox(height: 8),
                        Text(
                          '安装完成后可在此查看命令执行记录',
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                        ),
                      ],
                    ),
                  );
                }

                // 自动滚到底部
                if (_autoScroll && _scrollController.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final line = filtered[index];
                    final isSeparator = line.contains('───') && line.contains('日志');
                    final isError = !isSeparator && line.toLowerCase().contains('error');
                    final isWarn = !isSeparator && line.toLowerCase().contains('warn');
                    return SelectableText(
                      line,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isSeparator
                            ? AppColors.accent
                            : isError
                                ? theme.colorScheme.error
                                : isWarn
                                    ? AppColors.statusAmber
                                    : theme.colorScheme.onSurface,
                        fontWeight: isSeparator ? FontWeight.bold : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copyAll() {
    final provider = context.read<GatewayProvider>();
    final allLogs = _mergedLogs(provider.logs);
    final text = allLogs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(allLogs.isEmpty ? '无日志可复制' : '已复制 ${allLogs.length} 行日志')),
    );
  }
}
