class AppConstants {
  static const String appName = 'Hermes Android App';
  static const String version = '0.3.24';
  // build number bumped to +51 with the v0.3.19 old-problems fix batch
  static const String packageName = 'com.nxg.hermesagentmobile';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'const1981';
  static const String authorEmail = 'web@2st.cc';
  static const String githubUrl = 'https://github.com/const1981/hermes-agent-mobile-zh';
  static const String githubRepo = 'const1981/hermes-agent-mobile-zh';
  static const String license = 'MIT';

  static const String githubApiLatestRelease =
      'https://api.github.com/repos/const1981/hermes-agent-mobile-zh/releases/latest';

  static const String orgName = 'Hermes Android App';
  static const String orgEmail = 'const1981@users.noreply.github.com';

  static const String gatewayHost = '127.0.0.1';
  static const int gatewayPort = 18789;
  static const String gatewayUrl = 'http://$gatewayHost:$gatewayPort';

  static const String ubuntuRootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';
  static const String rootfsAmd64 = '${ubuntuRootfsUrl}amd64.tar.gz';

  /// Hermes Agent 源码镜像（全部走国内源，弃用 ghproxy / 直连 GitHub）。
  /// 首选用 CNB.cool 腾讯云镜像（腾讯云 CDN，国内几十 MB/s，最稳最快）；
  /// CNB 故障时兜底用 gitee 镜像。前一个失败自动切下一个。
  static const List<String> hermesAgentMirrorUrls = [
    'https://cnb.cool/hermesagent-cn/hermes-agent-cn-mirror.git',
    'https://gitee.com/mirrors/hermes-agent.git',
  ];

  /// proot 内 DNS：国内手机用 Google DNS(8.8.8.8) 常常解析失败，改用国内公共 DNS。
  static const String prootResolv =
      'nameserver 119.29.11.29\nnameserver 223.5.5.5\n';

  /// pip 安装走国内清华源（首选，最快最稳）；华为云为兜底源。
  static const String pipIndexUrl = 'https://pypi.tuna.tsinghua.edu.cn/simple';
  static const String pipFallbackUrl = 'https://repo.huaweicloud.com/repository/pypi/simple';

  /// apt 系统源替换为阿里云国内源（Ubuntu 官方源 archive.ubuntu.com 在国内极慢/超时，
  /// 这是手机上第四步卡顿的常见元凶）。安装前注入到 proot 的 sources.list。
  static const String aptMirrorHost = 'mirrors.aliyun.com';
  static const String aptMirrorUrl = 'http://mirrors.aliyun.com/ubuntu-ports';

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
