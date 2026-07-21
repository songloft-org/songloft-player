import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/responsive.dart';
import 'widgets/settings_category_content.dart';
import 'widgets/settings_master_detail.dart';
import '../../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = buildSettingsCategories(l10n);
    // 与 SettingsMasterDetail 共用同一布局判断，避免漂移导致车机超宽比下渲染
    // 移动端列表却不响应点击的「按钮失效」(songloft-org/songloft#268)。
    final isMobile = !context.useWideLayout;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: SettingsMasterDetail(
        categories: categories,
        selectedIndex: _selectedCategory,
        onCategorySelected: (i) {
          // 移动端二级页是真实路由（/settings/category/:index），让浏览器/系统
          // 返回键能回到设置一级列表（Web 上非路由的 setState 详情无历史条目）。
          // 宽屏 master-detail 仍在本页内同页切换。
          if (isMobile) {
            context.push('/settings/category/$i');
          } else {
            setState(() => _selectedCategory = i);
          }
        },
        contentBuilder: (_, index) => SettingsCategoryContent(index: index),
        header: const SettingsServerInfoCard(),
      ),
    );
  }
}
