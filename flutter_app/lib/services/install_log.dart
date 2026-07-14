import 'dart:io';
import '../services/native_bridge.dart';

/// 安装过程的命令日志：每步执行的命令 + proot 返回的输出都会写进来，
/// 同时保留在内存 buffer 供 UI 实时显示。日志文件落在 App 私有目录
/// (filesDir/hermes_install.log)，不需要存储权限也能写、能看。
class InstallLog {
  static File? _file;
  static final List<String> _buffer = [];

  static Future<File> get _logFile async {
    if (_file != null) return _file!;
    final filesDir = await NativeBridge.getFilesDir();
    _file = File('$filesDir/hermes_install.log');
    return _file!;
  }

  /// 清空旧日志（每次开始安装时调用）
  static Future<void> init() async {
    _buffer.clear();
    try {
      final f = await _logFile;
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _buffer.add('=== Hermes 安装日志 ${DateTime.now().toLocal()} ===');
  }

  /// 追加一行（同时进内存 buffer）
  static Future<void> append(String line) async {
    _buffer.add(line);
    // 防止无限增长
    if (_buffer.length > 3000) _buffer.removeAt(0);
    try {
      final f = await _logFile;
      await f.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// 内存中的日志（供 UI 实时显示）
  static List<String> get buffer => List.unmodifiable(_buffer);

  /// 读取完整日志文本（失败界面"查看完整日志"用）
  static Future<String> readAll() async {
    try {
      final f = await _logFile;
      if (await f.exists()) return await f.readAsString();
    } catch (_) {}
    return _buffer.join('\n');
  }

  /// 日志文件绝对路径
  static Future<String> get path async {
    try {
      return (await _logFile).path;
    } catch (_) {
      return '';
    }
  }
}
