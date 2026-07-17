import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  static const String appName = 'Hermes Android App';
  /// 兜底版本号（编译期默认值）。真实版本由 [initRealVersion] 运行时读取 APK
  /// versionName 填充，UI 一律用 [displayVersion]，杜绝「界面旧版本、实际新包」的
  /// 双版本源漂移（v0.3.45→3.47 曾因忘了改这道常量而显示成 3.45）。
  static String version = '0.3.48';
  static String? _realVersion;

  /// 运行时读取 APK 真实 versionName。必须在 main() 尽早 await 调用。
  static Future<void> initRealVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _realVersion = info.version;
    } catch (_) {
      // 读取失败则用兜底常量
    }
  }

  /// UI 显示用的真实版本号（优先 APK versionName，失败回退 [version]）。
  static String get displayVersion => _realVersion ?? version;

  // build number bumped to +51 with the v0.3.19 old-problems fix batch
  static const String packageName = 'com.nxg.hermesagentmobile';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'const1981';
  static const String authorEmail = 'web@2st.cc';
  static const String githubUrl = 'https://github.com/const1981/hermes-agent-mobile-zh';
  static const String githubRepo = 'const1981/hermes-agent-mobile-zh';
  static const String license = 'AGPL-3.0';

  static const String githubApiLatestRelease =
      'https://api.github.com/repos/const1981/hermes-agent-mobile-zh/releases/latest';

  /// 应用内更新（v0.3.39+）。更新源优先级：
  /// 1) 七牛云 const 桶（已绑定永久域名 m.ebmma.com，走 HTTP 明文绕过自签证书，
  ///    存于 hermesmb/ 目录，国内快、稳定）
  /// 2) GitHub Releases（兜底，国内偶尔慢）
  /// version.json 格式：{"version":"0.3.40","apk":"http://m.ebmma.com/hermesmb/hermes-agent-mobile-v0.3.40.apk","notes":"..."}
  static const String updateSourceQiniu =
      'http://m.ebmma.com/hermesmb/version.json';
  static const String updateSourceGithub =
      'https://api.github.com/repos/const1981/hermes-agent-mobile-zh/releases/latest';
  /// 优先用七牛；七牛 URL 仍是占位 TODO 时自动降级到 GitHub。
  static List<String> get updateSources {
    final List<String> list = [];
    if (!updateSourceQiniu.contains('TODO')) list.add(updateSourceQiniu);
    list.add(updateSourceGithub);
    return list;
  }
  static const String qiniuApkBaseUrl = 'http://m.ebmma.com/hermesmb';

  /// v0.3.44 起：所有下载源（rootfs / 更新）统一由七牛上的**中央清单文件** sources.json 决定，
  /// 不再硬编码具体地址。该清单地址是 App 里**唯一写死**的值（永久固定），以后你换源/换桶/
  /// 换版本标签，只改七牛上的 sources.json，App 无需重新发版。
  /// 拉取时带 ?_=时间戳 破除七牛 CDN 缓存（否则会读到旧清单）。
  static const String sourcesManifestUrl =
      'http://m.ebmma.com/hermesmb/sources.json';

  static String get _sourcesManifestUrlNoCache =>
      '$sourcesManifestUrl?_=${DateTime.now().millisecondsSinceEpoch}';

  /// 拉取七牛中央清单；失败（网络/解析/字段缺失）返回 null，调用方回退硬编码地址。
  /// 超时 10s，绝不让初始化/更新检查卡死。
  static final Dio _manifestDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.json,
  ));

  static Future<Map<String, dynamic>?> _fetchSourcesManifest() async {
    try {
      final resp = await _manifestDio.get(_sourcesManifestUrlNoCache);
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {
      // 忽略一切异常 -> 回退硬编码
    }
    return null;
  }

  /// 解析指定架构的 rootfs 下载地址；清单不可用/字段缺失时回退硬编码七牛地址（getRootfsUrl）。
  static Future<String> resolveRootfsUrl(String arch) async {
    final m = await _fetchSourcesManifest();
    if (m != null) {
      try {
        final rootfs = m['rootfs'] as Map<String, dynamic>;
        final base = (rootfs['base_url'] as String?) ?? '';
        final files = rootfs['files'] as Map<String, dynamic>? ?? {};
        final name = files[arch] as String? ?? files['aarch64'] as String?;
        if (base.isNotEmpty && name != null && name.isNotEmpty) {
          return '$base$name';
        }
      } catch (_) {}
    }
    return getRootfsUrl(arch);
  }

  /// 解析 version.json 地址；清单不可用/缺失时回退硬编码七牛地址。
  static Future<String> resolveVersionJsonUrl() async {
    final m = await _fetchSourcesManifest();
    if (m != null) {
      try {
        final upd = m['update'] as Map<String, dynamic>? ?? {};
        final v = upd['version_json'] as String?;
        if (v != null && v.isNotEmpty) return v;
      } catch (_) {}
    }
    return updateSourceQiniu;
  }

  static const String orgName = 'Hermes Android App';
  static const String orgEmail = 'const1981@users.noreply.github.com';

  static const String gatewayHost = '127.0.0.1';
  static const int gatewayPort = 18789;
  static const String gatewayUrl = 'http://$gatewayHost:$gatewayPort';

  /// v0.3.42 起改用 Debian（proot-distro 官方 bookworm rootfs）。
  /// 来源：termux/proot-distro 官方 .tar.xz（已验证可经 XZCompressorInputStream 解压），
  /// v0.3.44 起**镜像到七牛 const/hermesmb**（m.ebmma.com 国内永久域名、HTTP 明文），
  /// 用七牛国内流量下载，解决 GitHub 海外源国内慢/不稳的问题。文件名与原 release 保持一致。
  /// 注：自 v0.3.44 起 rootfs 实际地址优先由七牛中央清单 sources.json 解析（见 resolveRootfsUrl），
  /// 这里的 debianRootfsBaseUrl / getRootfsUrl 仅作为清单不可用时的**兜底硬编码地址**。
  static const String debianRootfsBaseUrl =
      'http://m.ebmma.com/hermesmb/debian-bookworm-';
  static const String rootfsArm64 = '${debianRootfsBaseUrl}aarch64-pd-v4.17.3.tar.xz';
  static const String rootfsArmhf = '${debianRootfsBaseUrl}arm-pd-v4.17.3.tar.xz';
  static const String rootfsAmd64 = '${debianRootfsBaseUrl}x86_64-pd-v4.17.3.tar.xz';
  /// 解压后 rootfs 在 App 私有目录下的子目录名（原 ubuntu，现 debian）。
  static const String rootfsSubdir = 'debian';

  /// Hermes Agent 源码镜像（全部走国内源，弃用 ghproxy / 直连 GitHub）。
  /// 首选用 CNB.cool 腾讯云镜像（腾讯云 CDN，国内几十 MB/s，最稳最快）；
  /// CNB 故障时兜底用 gitee 镜像。前一个失败自动切下一个。
  static const List<String> hermesAgentMirrorUrls = [
    'https://cnb.cool/hermesagent-cn/hermes-agent-cn-mirror.git',
    'https://gitee.com/mirrors/hermes-agent.git',
  ];

  /// proot 内 DNS：统一使用国内公共 DNS（119.29.11.29 / 223.5.5.5），避免海外 DNS 解析失败。
  static const String prootResolv =
      'nameserver 119.29.11.29\nnameserver 223.5.5.5\n';

  /// pip 安装走国内清华源（首选，最快最稳）；华为云为兜底源。
  static const String pipIndexUrl = 'https://pypi.tuna.tsinghua.edu.cn/simple';
  static const String pipFallbackUrl = 'https://repo.huaweicloud.com/repository/pypi/simple';

  /// apt 系统源替换为清华国内 Debian 镜像（deb.debian.org 在国内极慢/超时，
  /// 这是手机初始化卡顿的常见元凶）。安装前注入到 proot 的 sources.list。
  static const String aptMirrorHost = 'mirrors.tuna.tsinghua.edu.cn';
  static const String aptMirrorUrl = 'https://mirrors.tuna.tsinghua.edu.cn/debian';

  static const int healthCheckIntervalMs = 5000;
  static const int maxAutoRestarts = 5;

  static const String channelName = 'com.nxg.hermesagentmobile/native';
  static const String eventChannelName = 'com.nxg.hermesagentmobile/gateway_logs';

  static String getRootfsUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return rootfsArm64;
      case 'arm':
        return rootfsArmhf;
      case 'x86_64':
        return rootfsAmd64;
      default:
        return rootfsArm64;
    }
  }
}
