import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PluginIcon extends StatelessWidget {
  final String? iconUrl;
  final String displayName;
  final double size;
  final Color? statusColor;

  const PluginIcon({
    super.key,
    this.iconUrl,
    required this.displayName,
    this.size = 40,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      final url = iconUrl!;
      final isSvg = url.toLowerCase().endsWith('.svg');
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 5),
        child: isSvg
            ? SvgPicture.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _buildFallback(),
                errorBuilder: (_, _, _) => _buildFallback(),
              )
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildFallback(),
              ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final color = statusColor ?? _generateColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.extension, color: color, size: size * 0.6),
    );
  }

  Color _generateColor() {
    final hash = displayName.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }
}

class PluginNavIcon extends StatelessWidget {
  final String? iconUrl;
  final double size;
  final Widget fallbackIcon;

  const PluginNavIcon({
    super.key,
    this.iconUrl,
    this.size = 24,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (iconUrl == null || iconUrl!.isEmpty) return fallbackIcon;
    final url = iconUrl!;
    final isSvg = url.toLowerCase().endsWith('.svg');
    return SizedBox(
      width: size,
      height: size,
      child: isSvg
          ? SvgPicture.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => fallbackIcon,
              errorBuilder: (_, _, _) => fallbackIcon,
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallbackIcon,
            ),
    );
  }
}
