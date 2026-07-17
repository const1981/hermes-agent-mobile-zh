import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';

/// 全局常驻的终端会话管理器。
///
/// 终端进程（proot 内的 Hermes 对话）以前活在 TerminalScreen 的 State 里，
/// 一返回就被 dispose() 杀死，再进要冷启动等半天。现在把它提升为进程级单例：
/// - 第一次进入终端时启动 proot/Hermes 并保持；
/// - 离开终端（dispose）不再 kill，进程继续在后台跑；
/// - 再次进入直接复用同一 Pty，秒回对话，不重新初始化。
///
/// 只在 App 整体销毁（NativeBridge.stopTerminalService / 进程退出）时释放。
class TerminalSessionManager {
  TerminalSessionManager._();
  static final TerminalSessionManager instance = TerminalSessionManager._();

  Pty? _pty;
  bool _starting = false;
  // 用 var 而非 final：会话进程退出后必须换成全新的 Completer，
  // 否则下次 acquire() 会拿到已完成的旧 future，终端永久坏死。
  var _ready = Completer<Pty>();

  /// 已输出到终端的历史内容（用于再次进入时重放，避免空白）。
  /// 上限 200k 字符，约等于终端滚动历史，防止无限增长。
  String _bufferedOutput = '';
  String get bufferedOutput => _bufferedOutput;

  /// 已写入终端的回调（供 UI 把输出渲染出来）
  void Function(Uint8List)? onOutput;
  /// 进程退出回调
  void Function(int)? onExit;

  bool get isStarted => _pty != null;
  Pty? get pty => _pty;

  /// 获取（或启动）终端会话。并发调用也只启动一次。
  ///
  /// 关键修复：会话进程退出后（用户在 hermes 里 Ctrl-D 退出、或进程崩溃），
  /// 必须重置 `_ready` 以便下次调用能重新拉起新会话，否则会一直返回
  /// 已完成的旧 future（或已报错），导致终端「假死」——再进终端永远报错，
  /// 只能杀掉 App 重开（#终端退出后坏死）。
  Future<Pty> acquire() async {
    if (_pty != null) return _pty!;
    // 上一次会话已结束（_ready 已完成但 _pty 已清空）→ 开新会话。
    if (_ready.isCompleted) {
      _ready = Completer<Pty>();
    }
    if (_starting) return _ready.future;
    _starting = true;
    try {
      await _start();
      return _pty!;
    } catch (e) {
      _starting = false;
      // 允许下次重试
      rethrow;
    }
  }

  Future<void> _start() async {
    _bufferedOutput = ''; // 新会话：历史缓冲清零
    try { await NativeBridge.setupDirs(); } catch (_) {}
    try { await NativeBridge.writeResolv(); } catch (_) {}
    try {
      final filesDir = await NativeBridge.getFilesDir();
      const resolvContent = 'nameserver 119.29.11.29\nnameserver 223.5.5.5\n';
      final resolvFile = File('$filesDir/config/resolv.conf');
      if (!resolvFile.existsSync()) {
        Directory('$filesDir/config').createSync(recursive: true);
        resolvFile.writeAsStringSync(resolvContent);
      }
      final rootfsResolv = File('$filesDir/rootfs/debian/etc/resolv.conf');
      if (!rootfsResolv.existsSync()) {
        rootfsResolv.parent.createSync(recursive: true);
        rootfsResolv.writeAsStringSync(resolvContent);
      }
    } catch (_) {}

    final config = await TerminalService.getProotShellConfig();
    final args = TerminalService.buildProotArgs(config);
    _pty = Pty.start(
      config['executable']!,
      arguments: args,
      environment: TerminalService.buildHostEnv(config),
      columns: 80,
      rows: 24,
    );

    _pty!.output.cast<List<int>>().listen((data) {
      final bytes = Uint8List.fromList(data);
      onOutput?.call(bytes);
      // 累积历史输出，供再次进入时重放（带上限保护）
      _bufferedOutput += utf8.decode(data, allowMalformed: true);
      if (_bufferedOutput.length > 200000) {
        _bufferedOutput =
            _bufferedOutput.substring(_bufferedOutput.length - 200000);
      }
    });
    _pty!.exitCode.then((code) {
      onExit?.call(code);
      _pty = null;
      _starting = false;
      // 重置 ready 为全新 Completer，使下次 acquire() 能重新拉起会话，
      // 而不是拿到已完成的旧 future（那样会让终端在第一次会话结束后永久坏死）。
      _ready = Completer<Pty>();
    });

    _ready.complete(_pty!);
  }

  /// 主动释放（App 退出时调用）。离开终端页不要调用此方法。
  void disposeSession() {
    _pty?.kill();
    _pty = null;
  }
}
