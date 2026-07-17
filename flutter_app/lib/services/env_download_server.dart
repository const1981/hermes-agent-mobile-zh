import 'dart:io';

/// 在 App 内起一个临时 HTTP 服务，让同一 WiFi 下的电脑浏览器直接下载手机里的环境 zip。
/// 纯 Dart 实现（dart:io），不依赖外部存储权限；绑定 0.0.0.0 随机端口，返回可访问 URL。
class EnvDownloadServer {
  HttpServer? _server;
  int port = 0;
  String? ip;

  bool get isRunning => _server != null;

  /// 启动服务并 serve [filePath]。返回形如 http://192.168.x.x:port/ 的访问地址。
  Future<String> start(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    port = _server!.port;
    ip = await _localIp();

    _server!.listen((HttpRequest req) async {
      try {
        if (req.uri.path == '/download' || req.uri.path == '/hermes_env.zip') {
          final len = await file.length();
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.binary;
          req.response.headers.set(
            'Content-Disposition',
            'attachment; filename="hermes_env.zip"',
          );
          req.response.contentLength = len;
          await req.response.addStream(file.openRead());
        } else {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.html;
          req.response.write('''
<!doctype html><html lang="zh"><head><meta charset="utf-8">
<title>Hermes 环境镜像</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:560px;margin:48px auto;padding:0 16px;color:#222}
h1{font-size:20px;margin-bottom:8px}
p{line-height:1.6;color:#444}
a{display:inline-block;margin-top:18px;padding:13px 22px;background:#1976d2;color:#fff;border-radius:9px;text-decoration:none;font-weight:600;font-size:15px}
.meta{color:#888;font-size:13px;margin-top:24px;word-break:break-all;background:#f5f5f5;padding:10px 12px;border-radius:8px}
</style></head><body>
<h1>📦 Hermes 环境镜像导出</h1>
<p>这是你手机里装好的整套环境（Debian + Python + Hermes + 全部依赖）打包成的 zip。</p>
<a href="/download">⬇️ 点击下载 hermes_env.zip</a>
<div class="meta">源文件：${filePath}</div>
<div class="meta">手机 IP：$ip &nbsp; 端口：$port</div>
</body></html>''');
        }
      } catch (_) {
        // 忽略单个请求异常，避免整个服务崩
      } finally {
        await req.response.close();
      }
    });

    return 'http://$ip:$port/';
  }

  /// 停止服务
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  /// 取手机当前 WiFi 的 IPv4 地址（优先 192.168 / 10 / 172 网段）。
  static Future<String> _localIp() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final i in ifaces) {
        for (final a in i.addresses) {
          final s = a.address;
          if (s.startsWith('192.168.') ||
              s.startsWith('10.') ||
              s.startsWith('172.')) {
            return s;
          }
        }
      }
      if (ifaces.isNotEmpty) {
        return ifaces.first.addresses.first.address;
      }
    } catch (_) {
      // 取不到就用回环
    }
    return '127.0.0.1';
  }
}
