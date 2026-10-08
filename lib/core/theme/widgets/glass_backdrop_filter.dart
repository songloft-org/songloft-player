import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Remove the filter itself when glass is opaque, rather than blurring unseen pixels.
class GlassBackdropFilter extends StatelessWidget {
  final ImageFilter filter;
  final Widget child;

  const GlassBackdropFilter({
    super.key,
    required this.filter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    if (ext?.opaqueGlass == true) return child;
    return BackdropFilter(filter: filter, child: child);
  }
}
