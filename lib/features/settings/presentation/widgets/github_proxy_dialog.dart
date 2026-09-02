import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/constants/github_proxy.dart';

const _kAiPrompt =
    '请帮我找几个目前可用的 GitHub 文件加速/反代服务（GitHub proxy mirror），'
    '要求：1) 免费、无需注册；2) 支持代理 github.com 和 raw.githubusercontent.com 的文件下载；'
    '3) 用法是在原始 URL 前拼接代理前缀，如 https://代理地址/https://github.com/...。'
    '请给出 3-5 个可用的代理地址（以 https:// 开头、/ 结尾），并注明各自的特点。';

/// GitHub 加速代理选择弹窗：预设常用镜像 + 自定义地址，返回选定的代理前缀（空串表示直连）。
class GithubProxyDialog extends StatefulWidget {
  final String current;

  const GithubProxyDialog({super.key, required this.current});

  @override
  State<GithubProxyDialog> createState() => _GithubProxyDialogState();
}

class _GithubProxyDialogState extends State<GithubProxyDialog> {
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

    final ext = Theme.of(context).extension<SongloftThemeExtension>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ext.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AlertDialog(
          backgroundColor: ext.glassFill,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.cardRadius),
            side: BorderSide(color: ext.glassBorder, width: 0.5),
          ),
          title: Text(l10n.settingsGithubProxyTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsGithubProxyDialogDesc,
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
                          l10n.settingsGithubProxyCustom,
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
                if (_selected == -1) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: TextField(
                      controller: _customController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'https://your-proxy.com/',
                        helperText: l10n.settingsGithubProxyCustomHelper,
                        helperMaxLines: 2,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _kAiPrompt),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.settingsGithubProxyCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(l10n.settingsGithubProxyCopyPrompt),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
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
                final value =
                    _selected == -1
                        ? _customController.text.trim()
                        : presets[_selected].value;
                Navigator.pop(context, value);
              },
              child: Text(l10n.settingsSave),
            ),
          ],
        ),
      ),
    );
  }
}
