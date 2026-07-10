/// GitHub 代理预设选项。
///
/// 插件更新/商店、App 升级检查、客户端下载加速等处共用同一份预设，避免各处
/// 各自维护导致条目/顺序漂移。代理值为镜像前缀（以 `/` 结尾），空串表示直连。
class GithubProxyOption {
  final String label;
  final String value;

  const GithubProxyOption({required this.label, required this.value});
}

/// 预设 GitHub 代理列表（首项为「直连」）。
const List<GithubProxyOption> kGithubProxyPresets = [
  GithubProxyOption(label: '直连 (不使用代理)', value: ''),
  GithubProxyOption(label: 'ghproxy.com', value: 'https://ghproxy.com/'),
  GithubProxyOption(label: 'ghfast.top', value: 'https://ghfast.top/'),
  GithubProxyOption(label: 'gh.con.sh', value: 'https://gh.con.sh/'),
  GithubProxyOption(
    label: 'mirror.ghproxy.com',
    value: 'https://mirror.ghproxy.com/',
  ),
];
