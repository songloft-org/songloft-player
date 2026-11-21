import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/github_proxy_fallback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/github_plugin.dart';
import 'registry_plugin_icon.dart';

class GithubDiscoveryIcon extends ConsumerWidget {
  const GithubDiscoveryIcon({super.key, required this.plugin});

  final GithubPlugin plugin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = plugin.iconUrl;
    final proxy = ref.watch(githubProxyProvider).value;
    final prefix = proxy == null ? null : Uri.tryParse(proxy);
    final canProxy =
        prefix != null &&
        (prefix.scheme == 'https' || prefix.scheme == 'http') &&
        prefix.host.isNotEmpty &&
        prefix.userInfo.isEmpty &&
        !prefix.hasQuery &&
        !prefix.hasFragment;
    return RegistryPluginIcon(
      name: plugin.manifest.name,
      identity: plugin.repository.fullName,
      url: url != null && canProxy ? applyGithubProxy(url, proxy) : url,
      directUrl: url,
      bitmapFit: BoxFit.contain,
    );
  }
}
