import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import 'native_bridge.dart';

/// 应用内更新服务（v0.3.39+）。
///
/// 流程：检查更新 → 比对版本 → 下载 APK 到私有目录 → 调原生跳系统安装器。
/// 注意：Android 非 root 无法静默安装，最后一步必弹系统安装器让用户点一次。
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final Dio _dio = Dio();

  /// 版本号比较：a > b 返回 1，相等 0，a < b 返回 -1。
  /// 支持 "0.3.38" / "v0.3.38" 形式。
  int compareVersion(String a, String b) {
    final pa = _normalize(a).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = _normalize(b).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < len) pa.add(0);
    while (pb.length < len) pb.add(0);
    for (int i = 0; i < len; i++) {
      if (pa[i] != pb[i]) return pa[i] > pb[i] ? 1 : -1;
    }
    return 0;
  }

  String _normalize(String v) => v.replaceAll(RegExp(r'^[vV]'), '').trim();

  /// 单个更新源返回的解析结果。
  Future<UpdateInfo?> _fetchFromSource(String sourceUrl) async {
    try {
      final resp = await _dio.get(sourceUrl,
          options: Options(
            responseType: ResponseType.json,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ));
      final data = resp.data as Map<String, dynamic>;
      final latest = _normalize(data['version']?.toString() ?? '');
      if (latest.isEmpty) return null;
      String? apkUrl = data['apk']?.toString();
      // GitHub latest release 的特殊处理：从 assets 里取 .apk 链接
      if (apkUrl == null && sourceUrl.contains('api.github.com')) {
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final a in assets) {
          final name = (a['name'] ?? '').toString();
          if (name.endsWith('.apk')) {
            apkUrl = a['browser_download_url']?.toString();
            break;
          }
        }
      }
      if (apkUrl == null || apkUrl.isEmpty) return null;
      return UpdateInfo(
        version: latest,
        apkUrl: apkUrl,
        notes: data['notes']?.toString() ?? '',
        source: sourceUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// 依次尝试所有更新源，返回第一个能拿到且版本更新的结果。
  Future<UpdateInfo?> checkUpdate() async {
    for (final src in AppConstants.updateSources) {
      final info = await _fetchFromSource(src);
      if (info != null && compareVersion(info.version, AppConstants.version) > 0) {
        return info;
      }
    }
    return null; // 无更新或所有源失败
  }

  /// 下载 APK 到应用私有目录（apk_update/），返回本地路径。
  /// [onProgress] 回调：0.0 ~ 1.0。
  Future<String> downloadApk(UpdateInfo info,
      {void Function(double)? onProgress}) async {
    final dir = await getApplicationSupportDirectory();
    final apkDir = Directory('${dir.path}/apk_update');
    if (!await apkDir.exists()) await apkDir.create(recursive: true);
    final fileName =
        'hermes-agent-mobile-${info.version}.apk';
    final target = '${apkDir.path}/$fileName';

    await _dio.download(
      info.apkUrl,
      target,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    final f = File(target);
    if (!await f.exists()) {
      throw Exception('下载完成但文件不存在');
    }
    return target;
  }

  /// 下载并跳转系统安装器（一步到位）。
  Future<void> downloadAndInstall(UpdateInfo info,
      {void Function(double)? onProgress}) async {
    final path = await downloadApk(info, onProgress: onProgress);
    await NativeBridge.installApk(path);
  }
}

class UpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;
  final String source;
  UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.source,
  });
}
