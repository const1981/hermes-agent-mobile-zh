class AppConstants {
  static const String appName = 'Hermes Android App';
  static const String version = '0.3.8';
  static const String packageName = 'com.nxg.hermesagentmobile';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'const1981';
  static const String authorEmail = 'const1981@users.noreply.github.com';
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

  /// Hermes Agent 源码镜像源（按优先级排列，clone 时依次尝试，前一个失败自动切下一个）。
  /// 首选用国内镜像转发 GitHub，解决国内直连超时(exit 128)；后续可加入我们自建镜像 / gitee 等。
  static const List<String> hermesAgentMirrorUrls = [
    'https://ghproxy.net/https://github.com/nousresearch/hermes-agent.git',
    'https://github.com/nousresearch/hermes-agent.git',
  ];

  /// proot 内 DNS：国内手机用 Google DNS(8.8.8.8) 常常解析失败，改用国内公共 DNS。
  static const String prootResolv =
      'nameserver 119.29.11.29\nnameserver 223.5.5.5\n';

  /// pip 安装走国内清华源，更快更稳（默认 PyPI 国内慢）。
  static const String pipIndexUrl = 'https://pypi.tuna.tsinghua.edu.cn/simple';

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
