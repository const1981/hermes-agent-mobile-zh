import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';

/// 配置快照服务（v0.3.50 抽出集中化）。
///
/// 用途：把 App 私有目录里的「模型配置 + 渠道密钥」导出到**外部存储**
/// （Download/hermes-snapshot.json，卸载 App 不清除），作为卸载/重装的保护网。
///
/// 关键修复：早期 splash 自动导出只导 config.yaml、**漏掉 .env（含 Key）**，
/// 且文件名带版本号导致 import 读不到。这里统一：
///   - 导出必含 .env（密钥）；
///   - 写入 import 可读的通用路径 hermes-snapshot.json。
class SnapshotService {
  /// 快照存放路径：有存储权限放外部 Download/（卸载存活），否则放应用私有文档目录。
  static Future<String> getSnapshotPath() async {
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/hermes-snapshot.json';
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/hermes-snapshot.json';
  }

  /// 导出当前配置快照。
  /// [includeEnv] 默认 true：导出 config.yaml + .env（含 Key）+ autoStart。
  /// 返回实际写出的文件路径（用于 UI 提示）。
  static Future<String> exportSnapshot({bool includeEnv = true}) async {
    final hermesConfig =
        await NativeBridge.readRootfsFile('root/.hermes/config.yaml') ?? '';
    String hermesEnv = '';
    if (includeEnv) {
      hermesEnv = await NativeBridge.readRootfsFile('root/.hermes/.env') ?? '';
    }
    final prefs = PreferencesService();
    await prefs.init();
    final snapshot = {
      'version': AppConstants.displayVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'hermesConfig': hermesConfig,
      'hermesEnv': hermesEnv,
      'autoStart': prefs.autoStartGateway,
    };
    final path = await getSnapshotPath();
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );
    return path;
  }

  /// 从通用路径读取快照内容（不解压写盘）。找不到返回 null。
  static Future<Map<String, dynamic>?> readSnapshot() async {
    try {
      final path = await getSnapshotPath();
      final file = File(path);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 恢复快照到 rootfs（config.yaml + .env + autoStart）。
  /// 必须在 rootfs 已解压后调用（写盘路径依赖 root/.hermes/）。
  /// 返回是否成功恢复了非空内容。
  static Future<bool> importSnapshot() async {
    final snapshot = await readSnapshot();
    if (snapshot == null) return false;
    final hermesConfig = snapshot['hermesConfig'] as String?;
    final hermesEnv = snapshot['hermesEnv'] as String?;
    if ((hermesConfig == null || hermesConfig.isEmpty) &&
        (hermesEnv == null || hermesEnv.isEmpty)) {
      return false;
    }
    if (hermesConfig != null && hermesConfig.isNotEmpty) {
      await NativeBridge.writeRootfsFile('root/.hermes/config.yaml', hermesConfig);
    }
    if (hermesEnv != null && hermesEnv.isNotEmpty) {
      await NativeBridge.writeRootfsFile('root/.hermes/.env', hermesEnv);
    }
    final prefs = PreferencesService();
    await prefs.init();
    if (snapshot['autoStart'] != null) {
      prefs.autoStartGateway = snapshot['autoStart'] as bool;
    }
    return true;
  }
}
