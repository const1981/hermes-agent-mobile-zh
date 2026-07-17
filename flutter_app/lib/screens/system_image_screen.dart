import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';
import '../services/env_download_server.dart';

/// 后台递归计算目录总字节数（在 isolate 跑，避免卡 UI）。
int _calcDirSize(String path) {
  final dir = Directory(path);
  int total = 0;
  if (dir.existsSync()) {
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += e.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
  return total;
}

String _fmtSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  double v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// 系统镜像页：让你看到手机里装好的整套环境在哪、有多大、里面有什么，
/// 并一键打包 + 起局域网下载，把这一坨从手机导出到电脑研究。
class SystemImageScreen extends StatefulWidget {
  const SystemImageScreen({super.key});

  @override
  State<SystemImageScreen> createState() => _SystemImageScreenState();
}

class _SystemImageScreenState extends State<SystemImageScreen> {
  String _envPath = '';
  int _totalSize = 0;
  bool _sizeLoading = true;
  List<FileSystemEntity> _children = [];
  bool _childrenLoading = true;

  String _zipPath = '';
  int _zipSize = 0;
  bool _packing = false;

  final EnvDownloadServer _server = EnvDownloadServer();
  String _serverUrl = '';
  bool _serving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  Future<void> _init() async {
    String filesDir = '';
    try {
      filesDir = await NativeBridge.getFilesDir();
    } catch (_) {}
    final env = filesDir.isNotEmpty ? '$filesDir/rootfs/debian' : '(未知)';
    if (mounted) setState(() => _envPath = env);

    // 顶层目录浏览（让你「看到」文件夹）
    try {
      final dir = Directory(env);
      if (await dir.exists()) {
        final list = await dir.list().toList();
        list.sort((a, b) {
          final ad = a is Directory;
          final bd = b is Directory;
          if (ad != bd) return ad ? -1 : 1;
          return a.path.compareTo(b.path);
        });
        if (mounted) setState(() => _children = list);
      }
    } catch (_) {}
    if (mounted) setState(() => _childrenLoading = false);

    // 总大小（后台算，不卡 UI）
    try {
      if (await Directory(env).exists()) {
        final size = await compute(_calcDirSize, env);
        if (mounted) setState(() => _totalSize = size);
      }
    } catch (_) {}
    if (mounted) setState(() => _sizeLoading = false);
  }

  Future<void> _pack() async {
    if (_packing) return;
    setState(() => _packing = true);
    try {
      // 先显示提示：大目录可能需要几分钟
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始打包整个环境，目录较大可能需要 3~10 分钟，请耐心等待…'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      final p = await NativeBridge.packEnvZip();
      final f = File(p);
      final size = await f.exists() ? await f.length() : 0;
      if (mounted) setState(() {
        _zipPath = p;
        _zipSize = size;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 打包完成：${_fmtSize(size)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打包失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _packing = false);
    }
  }

  Future<void> _startServer() async {
    if (_zipPath.isEmpty) {
      await _pack();
      if (_zipPath.isEmpty) return;
    }
    try {
      final url = await _server.start(_zipPath);
      if (mounted) setState(() {
        _serverUrl = url;
        _serving = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动下载服务失败：$e')),
        );
      }
    }
  }

  Future<void> _stopServer() async {
    await _server.stop();
    if (mounted) setState(() {
      _serving = false;
      _serverUrl = '';
    });
  }

  Future<void> _copyPath() async {
    if (_envPath.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _envPath));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('路径已复制')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统镜像'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 环境位置 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_open, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('环境位置', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _copyPath,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _envPath,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(label: '总大小', value: _sizeLoading ? '计算中…' : _fmtSize(_totalSize)),
                      const SizedBox(width: 10),
                      _InfoChip(label: '顶层项目', value: _childrenLoading ? '…' : '${_children.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 文件夹内容（让你看到里面有什么） ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('里面有什么', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_childrenLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_children.isEmpty)
                    const Text('（空，可能还没初始化完成）', style: TextStyle(color: Colors.grey))
                  else
                    ..._children.map((e) {
                      final isDir = e is Directory;
                      final name = e.path.split('/').last;
                      return ListTile(
                        dense: true,
                        leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file,
                            color: isDir ? Colors.amber : Colors.blueGrey, size: 20),
                        title: Text(name, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                        subtitle: isDir ? const Text('文件夹') : null,
                        trailing: isDir ? null : const Text(''),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 操作 ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _packing ? null : _pack,
                    icon: _packing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.archive),
                    label: Text(_packing ? '打包中（大目录需几分钟）…' : '① 打包当前环境 (${_sizeLoading ? "…" : _fmtSize(_totalSize)})'),
                  ),
                  if (_zipPath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('已打包：$_zipPath\n大小：${_fmtSize(_zipSize)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _serving ? null : _startServer,
                    icon: const Icon(Icons.wifi),
                    label: Text(_serving ? '下载服务运行中…' : '② 启动局域网下载'),
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 8),
                  if (_serving) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('电脑浏览器打开下面地址即可下载：',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          SelectableText(
                            _serverUrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _stopServer,
                            icon: const Icon(Icons.stop_circle, size: 16),
                            label: const Text('停止服务'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '提示：手机和电脑需连同一 WiFi。若电脑打不开，检查路由器是否禁用了「AP 隔离」。',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(text: '$label：', style: const TextStyle(color: Colors.grey)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
