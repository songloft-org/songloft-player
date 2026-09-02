import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/network/github_proxy_fallback.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/web_os.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'widgets/section_card.dart';

/// 客户端下载页（仅 Web 访问时可达）。
///
/// 按浏览器 User-Agent 推荐匹配当前设备的原生客户端，并列出全部平台：
/// - 标准版：连接当前服务器（`songloft-org/songloft-player` releases）
/// - Bundle 版：内嵌后端、无需服务器（`songloft-org/songloft` releases）
///
/// 下载链接自动套用「设置 → 网络设置」配置的 GitHub 加速代理（[githubProxyProvider]）。
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
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, context.navScrollInset),
        children: [
          Text(
            l10n.settingsClientDownloadIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_recommendedCard(context, os, proxy) case final card?) ...[
            card,
            const SizedBox(height: AppSpacing.lg),
          ],
          SectionCard(
            title: l10n.settingsClientDownloadStandardSection,
            icon: Icons.dns_outlined,
            children: _buildTiles(
              context,
              _standardAssets,
              _standardBase,
              os,
              proxy,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: l10n.settingsClientDownloadBundleSection,
            icon: Icons.phone_android_outlined,
            children: _buildTiles(
              context,
              _bundleAssets,
              _bundleBase,
              os,
              proxy,
            ),
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
              Icon(
                Icons.recommend_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
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
                  onPressed:
                      () => _launch(
                        applyGithubProxy(
                          '$_standardBase${standard.asset}',
                          proxy,
                        ),
                      ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    l10n.settingsClientDownloadStandardBtn(standard.label),
                  ),
                ),
              if (bundle != null)
                OutlinedButton.icon(
                  onPressed:
                      () => _launch(
                        applyGithubProxy('$_bundleBase${bundle.asset}', proxy),
                      ),
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
            style:
                highlighted
                    ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    : null,
          ),
          subtitle:
              a.unsigned ? Text(l10n.settingsClientDownloadNoteUnsigned) : null,
          trailing:
              highlighted
                  ? Icon(Icons.download_outlined, color: colorScheme.primary)
                  : const Icon(Icons.download_outlined),
          onTap: () => _launch(applyGithubProxy('$base${a.asset}', proxy)),
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
      onPressed: () => _launch(applyGithubProxy(url, proxy)),
      icon: Icon(Icons.open_in_new, size: 16, color: colorScheme.primary),
      label: Text(label, style: TextStyle(color: colorScheme.primary)),
    );
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
