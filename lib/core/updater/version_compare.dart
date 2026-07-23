/// 热更新版本比较工具（前端 flutter_patcher 与后端 libgojni.so 补丁共享）。
///
/// 分渠道规则（见 docs/cn/backend_hotupdate.md、flutter_patcher_hotupdate.md）：
/// - **dev**：用 **git commit hash** 比较，hash 不同即视为有更新（hash 缺失时回退
///   build_time 比较，10 分钟容差规避同一次 CI 不同 job 的时间偏差）。
/// - **stable**：用**版本号**（semver 三段）比较，远端 > 本地即有更新。
///
/// 逻辑对齐 `FrontendVersionApi._isNewerVersion`，抽出为独立函数供前后端复用。
library;

/// 解析 `YYYY-MM-DD_HH:MM:SS` 形式的构建时间；空/`unknown`/非法 → null。
DateTime? parseBuildTime(String? buildTime) {
  if (buildTime == null || buildTime.isEmpty || buildTime == 'unknown') {
    return null;
  }
  return DateTime.tryParse(buildTime.replaceFirst('_', 'T'));
}

/// 判断远端是否比本地更新。
///
/// - [isDev]：当前构建是否为 dev 渠道。
/// - dev：优先比 [localGitCommit] vs [remoteGitCommit]（均非空且本地非 `unknown`
///   时，hash 不同 = 有更新）；否则回退 [localBuildTime] vs [remoteBuildTime]。
/// - stable：比 [localVersion] vs [remoteVersion]（三段 semver）。
bool isRemoteNewer({
  required bool isDev,
  String localVersion = '',
  String remoteVersion = '',
  String? localGitCommit,
  String? remoteGitCommit,
  DateTime? localBuildTime,
  DateTime? remoteBuildTime,
}) {
  if (isDev) {
    // dev 渠道：优先 git commit 比较
    if (remoteGitCommit != null &&
        remoteGitCommit.isNotEmpty &&
        localGitCommit != null &&
        localGitCommit.isNotEmpty &&
        localGitCommit != 'unknown') {
      return remoteGitCommit != localGitCommit;
    }
    // 回退到构建时间比较
    if (remoteBuildTime == null || localBuildTime == null) return false;
    final diff = remoteBuildTime.difference(localBuildTime);
    // 同一次 CI 的 build_time 可能因不同 job 产生数分钟偏差，10 分钟内视为同一构建。
    if (diff.inMinutes.abs() < 10) return false;
    return remoteBuildTime.isAfter(localBuildTime);
  }

  // stable 渠道：语义化版本三段比较
  if (remoteVersion.isEmpty || remoteVersion == 'dev') return false;
  final localParts =
      _normalize(localVersion).split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final remoteParts =
      _normalize(remoteVersion).split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (localParts.length < 3) {
    localParts.add(0);
  }
  while (remoteParts.length < 3) {
    remoteParts.add(0);
  }
  for (int i = 0; i < 3; i++) {
    if (remoteParts[i] > localParts[i]) return true;
    if (remoteParts[i] < localParts[i]) return false;
  }
  return false; // 相同
}

/// 去掉版本号前缀 v/V。
String _normalize(String version) {
  if (version.startsWith('v') || version.startsWith('V')) {
    return version.substring(1);
  }
  return version;
}
