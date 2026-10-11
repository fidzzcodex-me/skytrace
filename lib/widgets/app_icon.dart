import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/core_provider.dart';
import '../theme/colors.dart';

final Map<String, Uint8List?> _iconCache = {};
final Map<String, Future<Uint8List?>> _iconPending = {};

class AppIcon extends ConsumerWidget {
  const AppIcon({super.key, required this.package, this.size = 20});

  final String package;
  final double size;

  Future<Uint8List?> _load(WidgetRef ref) {
    if (_iconCache.containsKey(package)) return Future.value(_iconCache[package]);
    return _iconPending.putIfAbsent(package, () async {
      try {
        final bytes = await ref.read(trafficRepositoryProvider).appIcon(package);
        _iconCache[package] = bytes;
        return bytes;
      } catch (_) {
        _iconCache[package] = null;
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(size * 0.28)),
      alignment: Alignment.center,
      child: FaIcon(FontAwesomeIcons.android, size: size * 0.6, color: AppColors.primaryBlue),
    );
    if (package.isEmpty || package == 'unknown') return fallback;
    if (_iconCache.containsKey(package)) {
      final bytes = _iconCache[package];
      return bytes == null ? fallback : _image(bytes);
    }
    return FutureBuilder<Uint8List?>(
      future: _load(ref),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return fallback;
        return _image(bytes);
      },
    );
  }

  Widget _image(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}
