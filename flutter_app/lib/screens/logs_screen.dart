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

/// 日志时间范围筛选
enum _LogRange { today, hour, day, all }

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  String _filter = '';
  _LogRange _range = _LogRange.today;

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

  /// 网关运行时日志行首为 UTC ISO8601 时间戳（如 2026-07-15T16:20:00.000Z）。
  /// 安装日志无时间戳，始终保留。按所选时间范围过滤网关日志。
  bool _withinRange(String line) {
    if (_range == _LogRange.all) return true;
    // 解析行首 ISO 时间戳（UTC）
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})').firstMatch(line);
    if (match == null) return true; // 无时间戳的行（如分隔线、安装日志）保留
    final ts = DateTime.tryParse('${match.group(1)}Z');
    if (ts == null) return true;
    final local = ts.toLocal();
    final now = DateTime.now();
    switch (_range) {
      case _LogRange.hour:
        return now.difference(local).inHours < 1;
      case _LogRange.day:
        return now.difference(local).inHours < 24;
      case _LogRange.today:
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      case _LogRange.all:
        return true;
    }
  }

  List<String> _filterByRange(List<String> gatewayLogs) {
    if (_range == _LogRange.all) return gatewayLogs;
    return gatewayLogs.where(_withinRange).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 合并日志：安装日志在前 + 分隔线 + Gateway 运行时日志（按时间范围过滤）在后
  List<String> _mergedLogs(List<String> gatewayLogs) {
    final filtered = _filterByRange(gatewayLogs);
    if (_installLines.isEmpty && filtered.isEmpty) return [];
    if (_installLines.isEmpty) return filtered;
    if (filtered.isEmpty) return _installLines;
    return [..._installLines, '─── Gateway 运行时日志 ───', ...filtered];
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
            icon: const Icon(Icons.clear_all),
            tooltip: '清空',
            onPressed: () {
              context.read<GatewayProvider>().clearLogs();
              _searchController.clear();
              setState(() => _filter = '');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空网关日志')),
              );
            },
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                Text('时间范围', style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<_LogRange>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _LogRange.today, label: Text('今天')),
                      ButtonSegment(value: _LogRange.hour, label: Text('近1小时')),
                      ButtonSegment(value: _LogRange.day, label: Text('近24小时')),
                      ButtonSegment(value: _LogRange.all, label: Text('全部')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (set) => setState(() => _range = set.first),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
