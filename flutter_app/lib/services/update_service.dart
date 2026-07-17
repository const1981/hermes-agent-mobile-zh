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
  /// 网络/解析异常时抛出 [UpdateFetchException]（不再静默吞掉，让上层区分"检查失败"）。
  Future<UpdateInfo?> _fetchFromSource(String sourceUrl) async {
    try {
      // 七牛 CDN(m.ebmma.com) 会缓存 version.json，导致拿不到最新版、误显"已是最新"。
      // 给非 GitHub 源加时间戳戳绕过缓存（实测该 CDN 按 query 区分缓存，加戳即取最新）。
      // GitHub API 不缓存版本列表，无需加戳。
      String effectiveUrl = sourceUrl;
      if (!sourceUrl.contains('api.github.com')) {
        final sep = sourceUrl.contains('?') ? '&' : '?';
        effectiveUrl = '$sourceUrl${sep}_=${DateTime.now().millisecondsSinceEpoch}';
      }
      final resp = await _dio.get(effectiveUrl,
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
    } on DioException catch (e) {
      throw UpdateFetchException(_describeDioError(e));
    } catch (e) {
      // 兜底：version.json 结构异常等非网络问题
      throw UpdateFetchException('解析更新信息失败：$e');
    }
  }

  /// 把 Dio 异常翻译成用户可读、可操作的提示（P0-②）。
  String _describeDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return '连接更新服务器超时，请检查网络后重试';
      case DioExceptionType.receiveTimeout:
        return '接收更新信息超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接更新服务器（DNS 解析失败或网络不通）';
      case DioExceptionType.badCertificate:
        return '更新服务器证书校验失败（可能被拦截）';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        return '更新服务器返回异常${code != null ? '($code)' : ''}';
      case DioExceptionType.cancel:
        return '已取消检查更新';
      default:
        return '检查更新失败：${e.message ?? e}';
    }
  }

  /// 依次尝试所有更新源，区分三种结果：
  /// - 有更新：返回 UpdateCheckResult(update != null)
  /// - 已是最新：返回 UpdateCheckResult()（update == null 且 checkFailed == false）
  /// - 检查失败：返回 UpdateCheckResult(checkFailed: true, errorMessage)
  /// v0.3.44 起：优先用七牛中央清单 sources.json 里的 version_json 地址（换源无需重发 App），
  /// 清单不可用时 resolveVersionJsonUrl 自动回退硬编码七牛地址；GitHub 作为最终兜底。
  Future<UpdateCheckResult> checkUpdate() async {
    final List<String> sources = [await AppConstants.resolveVersionJsonUrl()];
    sources.add(AppConstants.updateSourceGithub);
    String? lastError;
    bool anyFailed = false;
    for (final src in sources) {
      try {
        final info = await _fetchFromSource(src);
        if (info != null && compareVersion(info.version, AppConstants.displayVersion) > 0) {
          return UpdateCheckResult(update: info);
        }
      } on UpdateFetchException catch (e) {
        anyFailed = true;
        lastError = e.message;
      } catch (e) {
        anyFailed = true;
        lastError = '检查更新失败：$e';
      }
    }
    // 全部源都成功但无新版 → 已是最新；任一源失败 → 检查失败（不再误报"已是最新"）
    if (anyFailed) {
      return UpdateCheckResult(checkFailed: true, errorMessage: lastError);
    }
    return const UpdateCheckResult();
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

/// 检查更新结果：区分「有更新 / 已是最新 / 检查失败」三种情况（P0-②）。
class UpdateCheckResult {
  /// 非 null 表示发现可更新版本。
  final UpdateInfo? update;
  /// true 表示所有更新源都检查失败（网络/解析/DNS），而非"已是最新"。
  final bool checkFailed;
  /// checkFailed 时的可读错误，直接展示给用户。
  final String? errorMessage;

  const UpdateCheckResult({this.update, this.checkFailed = false, this.errorMessage});

  bool get hasUpdate => update != null;
  bool get upToDate => update == null && !checkFailed;
}

/// 检查更新过程中抛出的、已翻译为用户可读消息的异常。
class UpdateFetchException {
  final String message;
  UpdateFetchException(this.message);
}
