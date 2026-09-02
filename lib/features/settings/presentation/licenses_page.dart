import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import 'widgets/section_card.dart';

/// 开源许可页（songloft-org/songloft#341）。
///
/// 客户端二进制链接了 GPL-3.0-only 的 WebF（无链接例外），故整体按 GPL-3.0 分发，
/// 而源码仍是 Apache-2.0。GPLv3 §4/§5 要求分发时**随附**许可全文与「完整对应源码」
/// 的获取方式，这一页就是 App 内的履行入口。
///
/// **许可全文刻意内嵌为 Flutter asset 而非纯外链**：GPLv3 的用词是「随附一份本许可证
/// 的副本」，纯外链在离线设备（局域网自托管场景很常见）上拿不到全文，合规性存疑。
/// asset 在 `flutter build` 阶段就进了 flutter_assets/，晚于它的签名步骤
/// （APK/IPA/DMG/MSIX）完全不受影响，所以这条路子零签名风险且一次覆盖全部平台。
/// asset 声明见 `pubspec.yaml`。
///
/// **第三方依赖清单刻意不在 Dart 里重写一遍**，而是直接渲染仓库根的 `NOTICE` 文件
/// （同样内嵌为 asset）。手抄一份必然与 NOTICE 漂移，而 NOTICE 才是合规文本。
class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  /// GPL 全文 asset（与父仓库 `LICENSES/GPL-3.0.txt` 内容一致，md5 相同）。
  static const String gplAsset = 'LICENSES/GPL-3.0.txt';

  /// 第三方组件声明 asset。
  static const String noticeAsset = 'NOTICE';

  static const String _clientRepo =
      'https://github.com/songloft-org/songloft-player';
  static const String _serverRepo = 'https://github.com/songloft-org/songloft';
  static const String _webfRepo = 'https://github.com/openwebf/webf';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLicensesTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, context.navScrollInset),
        children: [
          SectionCard(
            title: l10n.licensesDistributionSection,
            icon: Icons.gavel_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.licensesDistributionHeadline,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Paragraph(l10n.licensesDistributionWhy),
                    _Paragraph(l10n.licensesDistributionSource),
                    _Paragraph(l10n.licensesDistributionWeb),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: l10n.licensesSourceSection,
            icon: Icons.source_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: _Paragraph(l10n.licensesSourceHint),
              ),
              _LinkTile(
                icon: Icons.phone_android,
                title: l10n.licensesSourceClient,
                url: _clientRepo,
              ),
              const Divider(height: 1),
              _LinkTile(
                icon: Icons.dns_outlined,
                title: l10n.licensesSourceServer,
                url: _serverRepo,
              ),
              const Divider(height: 1),
              _LinkTile(
                icon: Icons.web_outlined,
                title: l10n.licensesSourceWebf,
                url: _webfRepo,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: l10n.licensesTextsSection,
            icon: Icons.description_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.balance_outlined),
                title: Text(l10n.licensesGplTitle),
                subtitle: Text(l10n.licensesGplSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => LicenseTextPage(
                              title: l10n.licensesGplTitle,
                              assetPath: gplAsset,
                            ),
                      ),
                    ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(l10n.licensesNoticeTitle),
                subtitle: Text(l10n.licensesNoticeSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => LicenseTextPage(
                              title: l10n.licensesNoticeTitle,
                              assetPath: noticeAsset,
                            ),
                      ),
                    ),
              ),
              const Divider(height: 1),
              // Flutter 自带的逐包许可页（LicenseRegistry），覆盖 pubspec.lock 里
              // 的全部依赖，比 NOTICE 的「值得单独声明的 8 项」更详尽。
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: Text(l10n.licensesFlutterTitle),
                subtitle: Text(l10n.licensesFlutterSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => showLicensePage(
                      context: context,
                      applicationName: 'Songloft',
                      applicationLegalese:
                          '© 2024-2026 Songloft. Distributed under GPL-3.0.',
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// 只读许可全文页：从内嵌 asset 读文本，等宽字体 + 可选中 + 可整体复制。
class LicenseTextPage extends StatelessWidget {
  const LicenseTextPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // 用 DefaultAssetBundle 而不是顶层 rootBundle：测试里可以套 DefaultAssetBundle
      // 注入假 bundle，且 Web 上走的是同一套缓存。
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.licensesLoadFailed(snapshot.error.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    // 许可全文是硬折行的等宽文本，行宽由文件本身决定。宽屏上
                    // SelectableText 会收缩到内容宽度然后被居中（实测桌面宽度下整块
                    // 文本右移了 ~200px），所以显式 Align 到左上；同时 maxWidth 兜住
                    // 超宽窗口，避免行首行尾距离过远影响阅读。
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: SelectableText(
                          text,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontFamilyFallback: ['Courier'],
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_all_outlined),
                      label: Text(l10n.licensesCopyAll),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ResponsiveSnackBar.showSuccess(
                          context,
                          message: l10n.licensesCopied,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.title, required this.url});

  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);
        if (ok || !context.mounted) return;
        ResponsiveSnackBar.showError(
          context,
          message: l10n.licensesOpenFailed(url),
        );
      },
    );
  }
}
