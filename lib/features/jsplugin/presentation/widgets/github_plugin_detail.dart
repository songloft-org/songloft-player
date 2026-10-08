import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/base_url_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/github_plugin.dart';
import '../providers/github_discovery_provider.dart';
import '../providers/jsplugin_provider.dart';

class GithubPluginDetail extends ConsumerStatefulWidget {
  final GithubPlugin plugin;
  const GithubPluginDetail({required this.plugin, super.key});
  @override
  ConsumerState<GithubPluginDetail> createState() => _GithubPluginDetailState();
}

class _GithubPluginDetailState extends ConsumerState<GithubPluginDetail> {
  bool _installing = false;

  Future<void> _open(String address) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (!await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('open');
      }
    } catch (_) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.githubDiscoveryOpenFailed,
        );
      }
    }
  }

  Future<void> _install() async {
    if (_installing) return;
    final plugin = widget.plugin;
    final l10n = AppLocalizations.of(context);
    final server = ref.read(baseUrlProvider);
    final installed = ref.read(jsPluginsProvider);
    final host = ref.read(serverVersionProvider);
    if (!installed.hasValue ||
        installed.isLoading ||
        installed.hasError ||
        pluginHostCompatibility(
              plugin.manifest.minHostVersion,
              host.value?.version,
            ) !=
            PluginHostCompatibility.compatible) {
      return;
    }
    final occupied =
        installed.requireValue
            .where((item) => item.entryPath == plugin.manifest.entryPath)
            .firstOrNull;
    final local =
        ref.read(githubDiscoveryInstallsProvider)[plugin.manifest.entryPath];
    final same =
        local != null
            ? local.repository.id == plugin.repository.id
            : plugin.installedFrom(occupied);
    final version = local?.manifest.version ?? occupied?.version ?? '';
    if (same && version == plugin.manifest.version) return;
    final replacing = (local != null || occupied != null) && !same;
    setState(() => _installing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(l10n.githubDiscoveryInstallTitle),
              scrollable: true,
              content: Text(
                '${l10n.githubDiscoveryInstallWarning(plugin.repository.fullName, plugin.manifest.version)}'
                '${replacing ? '\n\n${l10n.githubDiscoveryReplaceWarning(local?.manifest.name ?? occupied!.displayName, version)}' : ''}'
                '\n\n${l10n.githubDiscoveryPermissions}: ${plugin.manifest.permissions.isEmpty ? l10n.githubDiscoveryNoPermissions : plugin.manifest.permissions.join(', ')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  key: const ValueKey('github-install-confirm'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    replacing
                        ? l10n.jspluginConflictDialogConfirm
                        : l10n.jspluginInstall,
                  ),
                ),
              ],
            ),
      );
      if (confirmed != true ||
          !mounted ||
          server != ref.read(baseUrlProvider)) {
        return;
      }
      // Recheck after the confirmation: installed data/host can change while it is open.
      final fresh = ref.read(jsPluginsProvider);
      if (fresh.isLoading ||
          fresh.hasError ||
          !fresh.hasValue ||
          pluginHostCompatibility(
                plugin.manifest.minHostVersion,
                ref.read(serverVersionProvider).value?.version,
              ) !=
              PluginHostCompatibility.compatible) {
        return;
      }
      final current =
          fresh.requireValue
              .where((item) => item.entryPath == plugin.manifest.entryPath)
              .firstOrNull;
      if (current?.id != occupied?.id ||
          current?.version != occupied?.version ||
          ref.read(githubDiscoveryInstallsProvider)[plugin
                  .manifest
                  .entryPath] !=
              local) {
        return;
      }
      final proxy = ref.read(githubProxyProvider).value ?? '';
      final installs = ref.read(githubDiscoveryInstallsProvider.notifier);
      final result = await ref
          .read(jsPluginApiProvider)
          .installFromRegistry(
            downloadUrl: plugin.downloadUrl,
            githubProxy: proxy.isEmpty ? null : proxy,
            overwrite: occupied != null || local != null,
          );
      if (result.success > 0) {
        if (!installs.installed(plugin, server: server)) return;
        if (mounted) {
          ResponsiveSnackBar.showSuccess(context, message: result.message);
        }
      } else if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message:
              result.results.firstOrNull?.error ??
              l10n.githubDiscoveryInstallFailed,
        );
      }
    } catch (error) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message:
              error is ApiException
                  ? error.message
                  : l10n.githubDiscoveryInstallFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final installed = ref.watch(jsPluginsProvider);
    final host = ref.watch(serverVersionProvider);
    final local =
        ref.watch(githubDiscoveryInstallsProvider)[plugin.manifest.entryPath];
    final occupied =
        installed.value
            ?.where((item) => item.entryPath == plugin.manifest.entryPath)
            .firstOrNull;
    final same =
        local != null
            ? local.repository.id == plugin.repository.id
            : plugin.installedFrom(occupied);
    final version = local?.manifest.version ?? occupied?.version ?? '';
    final already = same && version == plugin.manifest.version;
    final compatibility = pluginHostCompatibility(
      plugin.manifest.minHostVersion,
      host.value?.version,
    );
    final installedReady =
        installed.hasValue && !installed.isLoading && !installed.hasError;
    final canInstall =
        installedReady &&
        compatibility == PluginHostCompatibility.compatible &&
        !_installing &&
        !already;
    final replacing = (local != null || occupied != null) && !same;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plugin.manifest.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.jspluginClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.githubDiscoveryNotice,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            SelectableText(plugin.repository.fullName),
            const SizedBox(height: 12),
            Text(plugin.manifest.description),
            const SizedBox(height: 12),
            Text(
              'v${plugin.manifest.version} · ${plugin.manifest.renderEngine.isEmpty ? 'webview' : plugin.manifest.renderEngine} · ★ ${plugin.repository.stars}',
            ),
            Text(
              l10n.githubDiscoveryPublished(
                plugin.publishedAt.split('T').first,
              ),
            ),
            if (plugin.manifest.minHostVersion.isNotEmpty)
              Text(
                l10n.githubDiscoveryMinimumHost(plugin.manifest.minHostVersion),
              ),
            const SizedBox(height: 20),
            Text(
              l10n.githubDiscoveryPermissions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              plugin.manifest.permissions.isEmpty
                  ? l10n.githubDiscoveryNoPermissions
                  : plugin.manifest.permissions.join(', '),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed:
                      () => _open(
                        'https://github.com/${plugin.repository.fullName}',
                      ),
                  icon: const Icon(Icons.code),
                  label: Text(l10n.githubDiscoverySource),
                ),
                TextButton.icon(
                  onPressed: () => _open(plugin.releaseUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.githubDiscoveryRelease),
                ),
              ],
            ),
            if (replacing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.githubDiscoveryReplaceWarning(
                    local?.manifest.name ?? occupied!.displayName,
                    version,
                  ),
                  style: TextStyle(color: colors.error),
                ),
              ),
            if (compatibility == PluginHostCompatibility.incompatible)
              Text(
                l10n.githubDiscoveryIncompatible,
                style: TextStyle(color: colors.error),
              ),
            if (compatibility == PluginHostCompatibility.unknown)
              TextButton(
                onPressed:
                    host.isLoading
                        ? null
                        : () => ref.invalidate(serverVersionProvider),
                child: Text(l10n.githubDiscoveryHostUnknown),
              ),
            if (!installedReady)
              TextButton(
                onPressed:
                    installed.isLoading
                        ? null
                        : () => ref.invalidate(jsPluginsProvider),
                child: Text(l10n.githubDiscoveryInstalledUnknown),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('github-plugin-install'),
              onPressed: canInstall ? _install : null,
              child: Text(
                _installing
                    ? l10n.commonLoading
                    : already
                    ? l10n.githubDiscoveryInstalled
                    : same &&
                        (comparePluginVersions(
                                  plugin.manifest.version,
                                  version,
                                ) ??
                                0) >
                            0
                    ? l10n.githubDiscoveryUpdateTo(plugin.manifest.version)
                    : same
                    ? l10n.jspluginReinstall
                    : l10n.jspluginInstall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
