/// Lightweight i18n: pure Map-based dictionary, zero extra dependencies.
/// Usage: `AppStrings.of(context).appName`
///
/// Supported locales:
///   - zh  (Simplified Chinese) – default
///   - en  (English)
///
/// To add a new string:
///   1. Add key to [_zh] and [_en] maps below
///   2. Add typed getter to [AppStrings]
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

// ── Typed accessors ────────────────────────────────────────────

class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    final loc = context.watch<LocaleProvider>().locale;
    return AppStrings(loc);
  }

  bool get isZh => locale.languageCode == 'zh';

  String t(String zhKey, {String? enKey}) => isZh ? (zhKey) : (enKey ?? zhKey);

  // ── App ──────────────────────────────────────
  String get appName           => isZh ? '赫尔墨斯'            : 'Hermes Agent';
  String get appSubtitle       => isZh ? 'Android AI 网关'     : 'AI Gateway for Android';
  String get appNameLong        => isZh ? '赫尔墨斯 Android'    : 'Hermes Android App';

  // ── Splash ───────────────────────────────────
  String get loading               => isZh ? '加载中...'              : 'Loading...';
  String get checkingSetup          => isZh ? '正在检查安装状态...'     : 'Checking setup status...';
  String get reinstallingPython     => isZh ? '正在重新安装 Python...'  : 'Reinstalling Python...';
  String get reinstallingHermes     => isZh ? '正在重新安装 Hermes...'  : 'Reinstalling Hermes Agent...';
  String get errorPrefix            => isZh ? '错误：'                : 'Error: ';

  // ── Dashboard ─────────────────────────────────
  String get quickActions           => isZh ? '快捷操作'               : 'QUICK ACTIONS';
  String get statusSection          => isZh ? '状态'                  : 'STATUS';
  String get onboardingTitle        => isZh ? '引导设置'               : 'Onboarding';
  String get onboardingDesc         => isZh ? '配置 API 密钥和绑定'     : 'Configure API keys and binding';
  String get configureTitle         => isZh ? '配置'                  : 'Configure';
  String get configureDesc          => isZh ? '编辑网关设置'           : 'Edit gateway settings';
  String get terminalTitle          => isZh ? '对话终端'              : 'Chat Terminal';
  String get terminalDesc           => isZh ? '打开 Proot Shell'      : 'Open a proot shell';
  String get logsTitle              => isZh ? '日志'                  : 'Logs';
  String get logsDesc               => isZh ? '查看网关日志'           : 'View gateway logs';
  String get gateway                => isZh ? '网关'                  : 'Gateway';

  // ── Settings ─────────────────────────────────
  String get settings               => isZh ? '设置'                  : 'Settings';
  String get generalSection         => isZh ? '通用'                  : 'GENERAL';
  String get autoStartGateway       => isZh ? '自动启动网关'           : 'Auto-start gateway';
  String get autoStartGatewayDesc   => isZh ? '应用启动时自动开启网关'   : 'Start the gateway when the app opens';
  String get batteryOptimization    => isZh ? '电池优化'              : 'Battery Optimization';
  String get batteryOptimized       => isZh ? '已优化（可能杀后台进程）': 'Optimized (may kill background sessions)';
  String get batteryUnrestricted    => isZh ? '无限制（推荐）'          : 'Unrestricted (recommended)';
  String get setupStorage           => isZh ? '存储权限'              : 'Setup Storage';
  String get storageGranted         => isZh ? '已授权 — Proot 可访问 /sdcard。如不需要可撤销。'
                                         : 'Granted — proot can access /sdcard. Revoke if not needed.';
  String get storageNotGranted      => isZh ? '未授权（推荐）— 仅在需要时点击授权'
                                         : 'Not granted (recommended) — tap to grant only if needed';
  String get sysInfoSection         => isZh ? '系统信息'              : 'SYSTEM INFO';
  String get architecture           => isZh ? '架构'                  : 'Architecture';
  String get prootPathLabel         => isZh ? 'Proot 路径'           : 'PRoot path';
  String get rootfs                 => isZh ? 'Rootfs'                : 'Rootfs'; // 技术术语保留英文
  String get installed              => isZh ? '已安装'                : 'Installed';
  String get notInstalled           => isZh ? '未安装'                : 'Not installed';
  String get pythonLabel            => isZh ? 'Python'               : 'Python'; // 技术术语保留英文
  String get hermesAgentLabel       => isZh ? 'Hermes Agent'        : 'Hermes Agent';
  String get maintenanceSection     => isZh ? '维护'                  : 'MAINTENANCE';
  String get cleanGarbage           => isZh ? '清理垃圾'               : 'Clean Garbage';
  String get cleanGarbageDesc       => isZh ? '清理 pip 缓存、__pycache__ 与临时文件，保留 Hermes 必需配置与环境' : 'Remove pip cache, __pycache__ and temp files; keep Hermes config & environment';
  String get cleanConfirm           => isZh ? '将清理环境内的缓存与临时文件（不影响已安装的 Hermes 配置与环境），确定继续？' : 'Clean caches and temp files inside the environment (Hermes config & environment are kept). Continue?';
  String get cleaning              => isZh ? '正在清理...'            : 'Cleaning...';
  String get confirm               => isZh ? '确定'                  : 'Confirm';
  String cleanDone(String size)     => isZh ? '清理完成，释放 $size'     : 'Cleanup done, freed $size';
  String cleanFailed(String e)     => isZh ? '清理失败：$e'            : 'Clean failed: $e';
  String get exportSnapshot         => isZh ? '导出快照'              : 'Export Snapshot';
  String get exportSnapshotDesc     => isZh ? '备份配置到 Downloads'   : 'Backup config to Downloads';
  String get backupData             => isZh ? '备份数据包'            : 'Backup Data Package';
  String get backupDataDesc         => isZh ? '备份整套已安装环境(系统镜像: Ubuntu/Python/Hermes/全部依赖)到 Download，用于一键还原'
                                         : 'Backup the full installed environment (system image) to Download for one-click restore';
  String get backupStarted          => isZh ? '正在打包系统镜像，文件较大请耐心等待…' : 'Packing system image, large file, please wait…';
  String backupSaved(String path)   => isZh ? '数据包已备份到：$path' : 'Data package backed up to: $path';
  String backupFailed(dynamic e)    => isZh ? '备份失败：$e'          : 'Backup failed: $e';
  String get importSnapshot         => isZh ? '导入快照'              : 'Import Snapshot';
  String get importSnapshotDesc     => isZh ? '从备份恢复配置'         : 'Restore config from backup';
  String get rerunSetup             => isZh ? '重新运行安装程序'       : 'Re-run setup';
  String get rerunSetupDesc         => isZh ? '重新安装或修复环境'     : 'Reinstall or repair the environment';
  String get aboutSection           => isZh ? '关于'                  : 'ABOUT';
  String aboutApp(String version) => isZh ? '赫尔墨斯 AI 网关\n版本 $version'
                                         : 'AI Gateway for Android\nVersion $version';
  String get github                 => isZh ? 'GitHub'               : 'GitHub';
  String get contact                => isZh ? '联系我们'              : 'Contact';
  String get licenseLabel           => isZh ? '许可证'               : 'License';
  String snapshotSaved(String path) => isZh ? '快照已保存到 $path'     : 'Snapshot saved to $path';
  String exportFailed(dynamic e)    => isZh ? '导出失败：$e'          : 'Export failed: $e';
  String noSnapshotFound(String path) => isZh ? '未找到快照文件 $path'   : 'No snapshot found at $path';
  String get snapshotRestored   => isZh ? '快照恢复成功，请重启网关以生效。'
                                         : 'Snapshot restored successfully. Restart the gateway to apply.';
  String importFailed(dynamic e)    => isZh ? '导入失败：$e'          : 'Import failed: $e';

  // ── Backup / Restore 系统镜像 ────────
  String get restoreData            => isZh ? '恢复数据(系统镜像)'      : 'Restore System Image';
  String get restoreDataDesc        => isZh ? '从备份镜像一键还原整个运行环境(Ghost 式)，相当于重装好系统'
                                         : 'One-click restore of the whole environment from a backup image (Ghost-style)';
  String get restoreStarted         => isZh ? '正在还原系统镜像，请稍候…' : 'Restoring system image, please wait…';
  String get restoreDone            => isZh ? '环境已还原，重启网关即可使用' : 'Environment restored. Restart the gateway to use it.';
  String get restoreFailedSimple    => isZh ? '恢复失败'              : 'Restore failed';
  String get noBackupFound          => isZh ? '未找到任何备份镜像（请先备份环境）' : 'No backup images found (back up first)';

  // ── Language selector ─────────────────────────
  String get language               => isZh ? '语言'                 : 'Language';
  String get followSystem           => isZh ? '跟随系统'             : 'Follow System';
  String get simplifiedChinese      => isZh ? '简体中文'             : '简体中文';
  String get english                => isZh ? 'English'             : 'English';

  // ── Gateway Controls ──────────────────────────
  String get copyUrl                => isZh ? '复制链接'             : 'Copy URL';
  String get urlCopied              => isZh ? '链接已复制到剪贴板'     : 'URL copied to clipboard';
  String get openDashboard          => isZh ? '打开仪表盘'           : 'Open dashboard';
  String get startGateway           => isZh ? '启动网关'             : 'Start Gateway';
  String get stopGateway            => isZh ? '停止网关'             : 'Stop Gateway';
  String get viewLogs               => isZh ? '查看日志'             : 'View Logs';
  String get runningStatus          => isZh ? '运行中'               : 'Running';
  String get startingStatus         => isZh ? '启动中'               : 'Starting';
  String get errorStatus            => isZh ? '错误'                 : 'Error';
  String get stoppedStatus          => isZh ? '已停止'               : 'Stopped';

  // ── Gateway State ─────────────────────────────
  String get stoppedText            => isZh ? '已停止'               : 'Stopped';
  String get startingText           => isZh ? '启动中...'            : 'Starting...';
  String get runningText            => isZh ? '运行中'               : 'Running';
  String get errorText              => isZh ? '错误'                 : 'Error';

  // ── Setup Wizard ─────────────────────────────
  String get setupHermesAgent       => isZh ? '安装赫尔墨斯'         : 'Setup Hermes Agent';
  String get setupProgressDesc      => isZh ? '首次安装约需 10-30 分钟，请保持网络畅通...'
                                         : 'First setup takes ~10-30 min. Keep network on.';
  String get setupInitialDesc       => isZh ? '将下载 Ubuntu、Python 和 Hermes Agent 到独立环境中'
                                         : 'This will download Ubuntu, Python, and Hermes Agent into a self-contained environment.';
  String get goToDashboard          => isZh ? '前往主界面'           : 'Go to Dashboard';
  String get beginSetup             => isZh ? '开始安装'             : 'Begin Setup';
  String get retrySetup             => isZh ? '重试安装'             : 'Retry Setup';
  String get storageHint            => isZh ? '需要约 500MB 存储空间和网络连接'
                                         : 'Requires ~500MB of storage and an internet connection';
  String get unknownError           => isZh ? '未知错误'             : 'Unknown error';
  String get setupComplete          => isZh ? '安装完成！'           : 'Setup complete!';
  String get downloadUbuntuRootfs   => isZh ? '下载 Ubuntu Rootfs'   : 'Download Ubuntu rootfs';
  String get extractRootfs          => isZh ? '解压 Rootfs'          : 'Extract rootfs';
  String get installPython          => isZh ? '安装 Python'          : 'Install Python';
  String get installHermesAgent     => isZh ? '安装 Hermes Agent'    : 'Install Hermes Agent';
  String get configureEnvironment   => isZh ? '配置环境'             : 'Configure environment';

  // ── Setup Steps (bootstrap_service) ──────────
  String get bootstrapComplete      => isZh ? '安装完成'             : 'Setup complete';
  String get bootstrapRequired      => isZh ? '需要安装'             : 'Setup required';
  String checkFailed(dynamic e)     => isZh ? '检查失败：$e'         : 'Failed to check status: $e';
  String get settingUpDirs          => isZh ? '正在创建目录...'      : 'Setting up directories...';
  String get downloadingRootfs      => isZh ? '正在下载 Ubuntu Rootfs...': 'Downloading Ubuntu rootfs...';
  String downloadingRootfsDetail(int mb, int totalMb) => isZh ? '下载中：$mb MB / $totalMb MB' : 'Downloading: $mb MB / $totalMb MB';
  String get extractingRootfsMsg     => isZh ? '正在解压 Rootfs（需要较长时间）...': 'Extracting rootfs (this takes a while)...';
  String get rootfsExtracted        => isZh ? 'Rootfs 解压完成'       : 'Rootfs extracted';
  String get fixingPermissions      => isZh ? '正在修复 Rootfs 权限...': 'Fixing rootfs permissions...';
  String get updatingPkgLists       => isZh ? '正在更新软件源列表...': 'Updating package lists...';
  String get installingBasePkgs     => isZh ? '正在安装基础包...': 'Installing base packages...';
  String get cloningHermesRepo      => isZh ? '正在克隆 Hermes Agent 仓库...': 'Cloning Hermes Agent repository...';
  String get installingPyDeps       => isZh ? '正在安装 Python 依赖...': 'Installing Python dependencies...';
  String get verifyingInstall       => isZh ? '正在验证 Hermes Agent 安装...': 'Verifying Hermes Agent installation...';
  String get hermesAgentInstalled   => isZh ? 'Hermes Agent 安装完成': 'Hermes Agent installed';
  String get envConfigured          => isZh ? '环境配置完成'         : 'Environment configured';
  String get setupCompleteReady     => isZh ? '安装完成！可以开始使用 Agent 了。': 'Setup complete! Ready to start the agent.';
  String downloadFailed(String msg) => isZh ? '下载失败：$msg。请检查网络连接。' : 'Download failed: $msg. Check your internet connection.';
  String setupFailed(dynamic e)     => isZh ? '安装失败：$e'          : 'Setup failed: $e';

  // ── Onboarding / Configure screens ───────────
  String get onboardingAppBar       => isZh ? '引导设置'             : 'Hermes Agent Onboarding';
  String get configureAppBar        => isZh ? '网关配置'             : 'Hermes Agent Configure';
  String get startingOnboarding     => isZh ? '正在启动引导...'      : 'Starting onboarding...';
  String get startingConfigure       => isZh ? '正在启动配置...'      : 'Starting configure...';
  String startOnboardingFailed(dynamic e) => isZh ? '启动引导失败：$e'      : 'Failed to start onboarding: $e';
  String startConfigureFailed(dynamic e) => isZh ? '启动配置失败：$e'      : 'Failed to start configure: $e';
  String startShellFailed(dynamic e) => isZh ? '启动终端失败：$e'      : 'Failed to start shell: $e';
  String get copiedToClipboard      => isZh ? '已复制到剪贴板'       : 'Copied to clipboard';
  String get retry                  => isZh ? '重试'                 : 'Retry';
  String get done                   => isZh ? '完成'                 : 'Done';
  String get goToDashBtn            => isZh ? '前往主界面'           : 'Go to Dashboard';
  String get openLink               => isZh ? '打开链接'             : 'Open Link';
  String get cancel                 => isZh ? '取消'                 : 'Cancel';
  String get copyBtn                => isZh ? '复制'                 : 'Copy';
  String get openBtn                => isZh ? '打开'                 : 'Open';
  String get linkCopied             => isZh ? '链接已复制'           : 'Link copied';
  String get noUrlInSelection       => isZh ? '选中内容中没有网址'     : 'No URL found in selection';
  String get copyTooltip            => isZh ? '复制'                 : 'Copy';
  String get openUrlTooltip         => isZh ? '打开链接'             : 'Open URL';
  String get pasteTooltip           => isZh ? '粘贴'                 : 'Paste';
  String get terminalAppBar         => isZh ? '对话终端'             : 'Chat Terminal';
  String get startingTerminal       => isZh ? '正在启动终端...'      : 'Starting terminal...';

  // ── Logs Screen ──────────────────────────────
  String get gatewayLogs            => isZh ? '网关日志'             : 'Gateway Logs';
  String get autoScrollOn           => isZh ? '自动滚动：开'         : 'Auto-scroll on';
  String get autoScrollOff          => isZh ? '自动滚动：关'         : 'Auto-scroll off';
  String get copyAll                => isZh ? '全部复制'             : 'Copy all';
  String get filterLogsPlaceholder  => isZh ? '筛选日志...'          : 'Filter logs...';
  String get noLogsYet              => isZh ? '暂无日志'             : 'No logs yet';
  String get allLogsCopied          => isZh ? '所有日志已复制'       : 'All logs copied';

  // ── Step Labels (setup_state) ────────────────
  String get stepCheckingStatus     => isZh ? '检查状态中...'        : 'Checking status...';
  String get stepDownloadingRootfs  => isZh ? '下载 Ubuntu Rootfs'   : 'Downloading Ubuntu rootfs';
  String get stepExtractingRootfs   => isZh ? '解压 Rootfs'          : 'Extracting rootfs';
  String get stepInstallingPython   => isZh ? '安装 Python'          : 'Installing Python';
  String get stepInstallingHermes   => isZh ? '安装 Hermes Agent'    : 'Installing Hermes Agent';
  String get stepConfiguringEnv     => isZh ? '配置环境'             : 'Configuring environment';
  String get stepCompleteLabel      => isZh ? '安装完成'             : 'Setup complete';
  String get stepErrorLabel         => isZh ? '错误'                 : 'Error';
}
