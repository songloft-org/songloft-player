import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/web_os.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/github_proxy.dart';
import 'providers/settings_provider.dart';
import 'widgets/section_card.dart';

/// 客户端下载页（仅 Web 访问时可达）。
///
/// 按浏览器 User-Agent 推荐匹配当前设备的原生客户端，并列出全部平台：
/// - 标准版：连接当前服务器（`songloft-org/songloft-player` releases）
/// - Bundle 版：内嵌后端、无需服务器（`songloft-org/songloft` releases）
///
/// 下载链接自动套用已配置的 GitHub 加速代理（[githubProxyProvider]）。
class ClientDownloadPage extends ConsumerWidget {
  const ClientDownloadPage({super.key});

  // release 资产直链前缀
  static const String _standardBase =
      'https://github.com/songloft-org/songloft-player/releases/latest/download/';
  static const String _bundleBase =
      'https://github.com/songloft-org/songloft/releases/latest/download/';

  // releases 页（兜底：直链资产名变动时仍可手动挑选）
  static const String _standardReleases = AppConfig.frontendReleasesUrl;
  static const String _bundleReleases =
      'https://github.com/songloft-org/songloft/releases/latest';

  static const List<_ClientAsset> _standardAssets = [
    _ClientAsset(
      os: WebOS.android,
      label: 'Android (ARM64)',
      icon: Icons.android,
      asset: 'songloft-arm64-v8a.apk',
    ),
    _ClientAsset(
      os: WebOS.android,
      label: 'Android (ARMv7)',
      icon: Icons.android,
      asset: 'songloft-armeabi-v7a.apk',
    ),
    _ClientAsset(
      os: WebOS.ios,
      label: 'iOS',
      icon: Icons.phone_iphone,
      asset: 'songloft-ios-nosign.ipa',
      unsigned: true,
    ),
    _ClientAsset(
      os: WebOS.windows,
      label: 'Windows (x64)',
      icon: Icons.desktop_windows,
      asset: 'songloft-windows-x64.zip',
    ),
    _ClientAsset(
      os: WebOS.macos,
      label: 'macOS',
      icon: Icons.laptop_mac,
      asset: 'songloft-macos.dmg',
    ),
    _ClientAsset(
      os: WebOS.linux,
      label: 'Linux (x64)',
      icon: Icons.laptop,
      asset: 'songloft-linux-x64.tar.gz',
    ),
  ];

  static const List<_ClientAsset> _bundleAssets = [
    _ClientAsset(
      os: WebOS.android,
      label: 'Android (ARM64)',
      icon: Icons.android,
      asset: 'songloft-bundled-android-arm64-v8a.apk',
    ),
    _ClientAsset(
      os: WebOS.android,
      label: 'Android (ARMv7)',
      icon: Icons.android,
      asset: 'songloft-bundled-android-armeabi-v7a.apk',
    ),
    _ClientAsset(
      os: WebOS.ios,
      label: 'iOS',
      icon: Icons.phone_iphone,
      asset: 'songloft-bundled-ios-nosign.ipa',
      unsigned: true,
    ),
    _ClientAsset(
      os: WebOS.windows,
      label: 'Windows (x64)',
      icon: Icons.desktop_windows,
      asset: 'songloft-bundled-windows-x64.zip',
    ),
    _ClientAsset(
      os: WebOS.macos,
      label: 'macOS',
      icon: Icons.laptop_mac,
      asset: 'songloft-bundled-macos.zip',
    ),
    _ClientAsset(
      os: WebOS.linux,
      label: 'Linux (x64)',
      icon: Icons.laptop,
      asset: 'songloft-bundled-linux-x64.tar.gz',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final os = detectWebOS();
    final proxy = ref.watch(githubProxyProvider).value ?? '';
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsClientDownloadTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.settingsClientDownloadIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: l10n.settingsClientDownloadAccelSection,
            icon: Icons.bolt_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(l10n.settingsClientDownloadGithubProxy),
                subtitle: Text(
                  proxy.isEmpty
                      ? l10n.settingsClientDownloadProxyNotConfigured
                      : proxy,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editProxy(context, ref, proxy),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_recommendedCard(context, os, proxy) case final card?) ...[
            card,
            const SizedBox(height: AppSpacing.lg),
          ],
          SectionCard(
            title: l10n.settingsClientDownloadStandardSection,
            icon: Icons.dns_outlined,
            children: _buildTiles(context, _standardAssets, _standardBase, os, proxy),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: l10n.settingsClientDownloadBundleSection,
            icon: Icons.phone_android_outlined,
            children: _buildTiles(context, _bundleAssets, _bundleBase, os, proxy),
          ),
          const SizedBox(height: AppSpacing.lg),
          _releasesLink(
            context,
            l10n.settingsClientDownloadStandardAllVersions,
            _standardReleases,
            proxy,
          ),
          _releasesLink(
            context,
            l10n.settingsClientDownloadBundleAllVersions,
            _bundleReleases,
            proxy,
          ),
        ],
      ),
    );
  }

  /// 顶部推荐卡片：命中访客 OS 时展示标准版（主）+ Bundle 版（次）快捷下载。
  Widget? _recommendedCard(BuildContext context, WebOS os, String proxy) {
    if (os == WebOS.unknown) return null;
    final standard = _firstFor(_standardAssets, os);
    final bundle = _firstFor(_bundleAssets, os);
    if (standard == null && bundle == null) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recommend_outlined, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.settingsClientDownloadRecommendFor(_osName(os)),
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (standard != null)
                FilledButton.icon(
                  onPressed: () =>
                      _launch(_applyProxy(proxy, '$_standardBase${standard.asset}')),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    l10n.settingsClientDownloadStandardBtn(standard.label),
                  ),
                ),
              if (bundle != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _launch(_applyProxy(proxy, '$_bundleBase${bundle.asset}')),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    l10n.settingsClientDownloadBundleBtn(bundle.label),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTiles(
    BuildContext context,
    List<_ClientAsset> assets,
    String base,
    WebOS os,
    String proxy,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[];
    for (var i = 0; i < assets.length; i++) {
      final a = assets[i];
      final highlighted = a.os == os;
      if (i > 0) tiles.add(const Divider(height: 1));
      tiles.add(
        ListTile(
          leading: Icon(a.icon),
          title: Text(
            a.label,
            style: highlighted
                ? TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )
                : null,
          ),
          subtitle: a.unsigned
              ? Text(l10n.settingsClientDownloadNoteUnsigned)
              : null,
          trailing: highlighted
              ? Icon(Icons.download_outlined, color: colorScheme.primary)
              : const Icon(Icons.download_outlined),
          onTap: () => _launch(_applyProxy(proxy, '$base${a.asset}')),
        ),
      );
    }
    return tiles;
  }

  Widget _releasesLink(
    BuildContext context,
    String label,
    String url,
    String proxy,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: () => _launch(_applyProxy(proxy, url)),
      icon: Icon(Icons.open_in_new, size: 16, color: colorScheme.primary),
      label: Text(label, style: TextStyle(color: colorScheme.primary)),
    );
  }

  /// 打开 GitHub 加速代理选择弹窗，选定后持久化到 [githubProxyProvider]（全局生效）。
  Future<void> _editProxy(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _GithubProxyDialog(current: current),
    );
    if (result == null || result == current) return;
    await ref.read(githubProxyProvider.notifier).setValue(result);
  }

  static _ClientAsset? _firstFor(List<_ClientAsset> assets, WebOS os) {
    for (final a in assets) {
      if (a.os == os) return a;
    }
    return null;
  }

  static String _osName(WebOS os) => switch (os) {
    WebOS.android => 'Android',
    WebOS.ios => 'iOS',
    WebOS.windows => 'Windows',
    WebOS.macos => 'macOS',
    WebOS.linux => 'Linux',
    WebOS.unknown => '',
  };

  /// 套用 GitHub 加速前缀（与后端 applyProxy 一致：确保结尾 `/` 后拼接原始 URL）。
  static String _applyProxy(String proxy, String url) {
    if (proxy.isEmpty) return url;
    final prefix = proxy.endsWith('/') ? proxy : '$proxy/';
    return '$prefix$url';
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ClientAsset {
  final WebOS os;
  final String label;
  final IconData icon;
  final String asset;
  final bool unsigned;

  const _ClientAsset({
    required this.os,
    required this.label,
    required this.icon,
    required this.asset,
    this.unsigned = false,
  });
}

/// GitHub 加速代理选择弹窗：预设常用镜像 + 自定义地址，返回选定的代理前缀（空串表示直连）。
class _GithubProxyDialog extends StatefulWidget {
  final String current;

  const _GithubProxyDialog({required this.current});

  @override
  State<_GithubProxyDialog> createState() => _GithubProxyDialogState();
}

class _GithubProxyDialogState extends State<_GithubProxyDialog> {
  late int _selected;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    const presets = kGithubProxyPresets;
    final idx = presets.indexWhere((p) => p.value == widget.current);
    // 命中预设则选中，否则视为自定义（-1）
    _selected = idx >= 0 ? idx : -1;
    _customController = TextEditingController(
      text: idx >= 0 ? '' : widget.current,
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    const presets = kGithubProxyPresets;

    return AlertDialog(
      title: Text(l10n.settingsClientDownloadGithubProxy),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsClientDownloadProxyDialogDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
              child: Column(
                children: [
                  ...List.generate(presets.length, (i) {
                    return RadioListTile<int>(
                      title: Text(
                        presets[i].value.isEmpty
                            ? l10n.githubProxyDirect
                            : presets[i].label,
                        style: theme.textTheme.bodyMedium,
                      ),
                      value: i,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                  RadioListTile<int>(
                    title: Text(
                      l10n.settingsClientDownloadCustomProxy,
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: -1,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (_selected == -1)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: TextField(
                  controller: _customController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'https://your-proxy.com/',
                    helperText: l10n.settingsClientDownloadCustomProxyHelper,
                    helperMaxLines: 2,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _selected == -1
                ? _customController.text.trim()
                : presets[_selected].value;
            Navigator.pop(context, value);
          },
          child: Text(l10n.settingsClientDownloadSave),
        ),
      ],
    );
  }
}
