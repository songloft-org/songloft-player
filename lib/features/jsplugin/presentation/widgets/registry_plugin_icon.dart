import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import 'plugin_icon_utils.dart';

class RegistryPluginIcon extends StatelessWidget {
  const RegistryPluginIcon({
    super.key,
    required this.name,
    required this.identity,
    this.url,
    this.directUrl,
    this.bitmapFit = BoxFit.cover,
  });

  final String name;
  final String identity;
  final String? url;
  final String? directUrl;
  final BoxFit bitmapFit;

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[identity.hashCode % Colors.primaries.length];
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final fallback = CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      foregroundColor: color,
      radius: 20,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    final address = url;
    final direct = directUrl;
    final isSvg = isSvgIconUrl(direct ?? address);
    final Widget content;
    if (address == null || address.isEmpty) {
      content = fallback;
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _image(
          address,
          isSvg,
          fallback,
          direct != null && direct != address
              ? () => _image(direct, isSvg, fallback, () => fallback)
              : () => fallback,
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: 40, child: content),
    );
  }

  Widget _image(
    String address,
    bool isSvg,
    Widget placeholder,
    Widget Function() onError,
  ) {
    if (isSvg) {
      return directUrl != null
          ? _DiscoverySvg(
            key: ValueKey(address),
            address: address,
            placeholder: placeholder,
            onError: onError,
          )
          : SvgPicture.network(
            address,
            key: ValueKey(address),
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => placeholder,
            errorBuilder: (_, _, _) => onError(),
          );
    }
    return Image.network(
      address,
      key: ValueKey(address),
      width: 40,
      height: 40,
      fit: bitmapFit,
      frameBuilder:
          (_, child, frame, synchronous) =>
              synchronous || frame != null ? child : placeholder,
      errorBuilder: (_, _, _) => onError(),
    );
  }
}

// Decode untrusted icons before handing their bytes to flutter_svg. Older
// flutter_svg and vector_graphics caches can emit unhandled load errors.
final _discoverySvgBytes = FutureProvider.autoDispose.family<ByteData, String>((
  ref,
  address,
) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.plain,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  final svg = (await dio.get<String>(address)).data;
  if (svg == null || svg.length > 256 * 1024) {
    throw const FormatException('Invalid discovery SVG');
  }
  return compute(
    (xml) =>
        vg
            .encodeSvg(
              xml: xml,
              debugName: 'GitHub discovery icon',
              enableClippingOptimizer: false,
              enableMaskingOptimizer: false,
              enableOverdrawOptimizer: false,
            )
            .buffer
            .asByteData(),
    svg,
  );
}, retry: (_, _) => null);

class _DiscoverySvg extends ConsumerWidget {
  const _DiscoverySvg({
    super.key,
    required this.address,
    required this.placeholder,
    required this.onError,
  });

  final String address;
  final Widget placeholder;
  final Widget Function() onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_discoverySvgBytes(address))
        .when(
          data:
              (bytes) => SvgPicture(
                _DecodedSvg(bytes),
                fit: BoxFit.contain,
                placeholderBuilder: (_) => placeholder,
                errorBuilder: (_, _, _) => onError(),
              ),
          error: (_, _) => onError(),
          loading: () => placeholder,
        );
  }
}

class _DecodedSvg extends BytesLoader {
  const _DecodedSvg(this.bytes);

  final ByteData bytes;

  @override
  bool operator ==(Object other) =>
      other is _DecodedSvg && identical(other.bytes, bytes);

  @override
  int get hashCode => identityHashCode(bytes);

  @override
  Future<ByteData> loadBytes(BuildContext? context) => SynchronousFuture(bytes);
}
