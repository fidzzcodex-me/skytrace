import 'package:flutter/material.dart';

import 'animations.dart';
import 'colors.dart';

enum SkyMood { overcast, brightening, clear, dusk }

@immutable
class SkyPalette {
  const SkyPalette({
    required this.top,
    required this.bottom,
    required this.cloud,
    required this.shade,
    required this.arc,
    required this.glow,
  });

  final Color top;
  final Color bottom;
  final Color cloud;
  final Color shade;
  final Color arc;
  final Color glow;

  static SkyPalette lerp(SkyPalette a, SkyPalette b, double t) {
    return SkyPalette(
      top: Color.lerp(a.top, b.top, t)!,
      bottom: Color.lerp(a.bottom, b.bottom, t)!,
      cloud: Color.lerp(a.cloud, b.cloud, t)!,
      shade: Color.lerp(a.shade, b.shade, t)!,
      arc: Color.lerp(a.arc, b.arc, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
    );
  }
}

class AppSky {
  const AppSky._();

  static SkyPalette of(SkyMood mood, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (mood) {
      case SkyMood.overcast:
        return dark
            ? const SkyPalette(
                top: Color(0xFF22344F),
                bottom: Color(0xFF15253B),
                cloud: Color(0x14FFFFFF),
                shade: Color(0x0AFFFFFF),
                arc: Color(0x338FA3BC),
                glow: Color(0x00FFFFFF),
              )
            : const SkyPalette(
                top: Color(0xFFD3DEEA),
                bottom: Color(0xFFEFF4F9),
                cloud: Color(0xBFFFFFFF),
                shade: Color(0xFFC4D2E1),
                arc: Color(0x599DB2C9),
                glow: Color(0x00FFFFFF),
              );
      case SkyMood.brightening:
        return dark
            ? const SkyPalette(
                top: Color(0xFF28507F),
                bottom: Color(0xFF15253B),
                cloud: Color(0x24FFFFFF),
                shade: Color(0x10FFFFFF),
                arc: Color(0x4087CEEB),
                glow: Color(0x1AFFFFFF),
              )
            : const SkyPalette(
                top: Color(0xFFBFE0F8),
                bottom: Color(0xFFEAF5FD),
                cloud: Color(0xCCFFFFFF),
                shade: Color(0xFFD6E9F7),
                arc: Color(0x6687CEEB),
                glow: Color(0x33FFFFFF),
              );
      case SkyMood.clear:
        return dark
            ? const SkyPalette(
                top: Color(0xFF2D6BB0),
                bottom: Color(0xFF1B3A62),
                cloud: Color(0x38FFFFFF),
                shade: Color(0x14FFFFFF),
                arc: Color(0x6687CEEB),
                glow: Color(0x2EFFFFFF),
              )
            : const SkyPalette(
                top: Color(0xFF8FC8F3),
                bottom: Color(0xFFE3F2FD),
                cloud: Color(0xEBFFFFFF),
                shade: Color(0xFFCFE7FA),
                arc: Color(0x80FFFFFF),
                glow: Color(0x66FFFFFF),
              );
      case SkyMood.dusk:
        return dark
            ? const SkyPalette(
                top: Color(0xFF5A4A3A),
                bottom: Color(0xFF2A2430),
                cloud: Color(0x24FFFFFF),
                shade: Color(0x10FFFFFF),
                arc: Color(0x66FFB300),
                glow: Color(0x33FFB300),
              )
            : const SkyPalette(
                top: Color(0xFFF6D6A8),
                bottom: Color(0xFFFFF3E0),
                cloud: Color(0xD9FFFFFF),
                shade: Color(0xFFF3E0C6),
                arc: Color(0x66FFB300),
                glow: Color(0x80FFE0A3),
              );
    }
  }

  static LinearGradient page(AppPalette p) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.gradientTop, p.background],
        stops: const [0, 0.42],
      );

  static Path cloudPath() => _unitCloud;

  static final Path _unitCloud = _buildCloud();

  static Path _buildCloud() {
    var path = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-62, -8, 124, 34), const Radius.circular(17)));
    final puffs = <Rect>[
      Rect.fromCircle(center: const Offset(-28, -8), radius: 22),
      Rect.fromCircle(center: const Offset(4, -20), radius: 30),
      Rect.fromCircle(center: const Offset(38, -6), radius: 20),
    ];
    for (final puff in puffs) {
      path = Path.combine(PathOperation.union, path, Path()..addOval(puff));
    }
    return path;
  }
}

class _CloudLayer {
  const _CloudLayer(this.y, this.scale, this.speed, this.alpha, this.phase);

  final double y;
  final double scale;
  final double speed;
  final double alpha;
  final double phase;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.palette, required Listenable repaint, required this.progress}) : super(repaint: repaint);

  final SkyPalette palette;
  final Animation<double> progress;

  static const List<_CloudLayer> _layers = [
    _CloudLayer(0.2, 0.62, 1, 0.55, 0.12),
    _CloudLayer(0.2, 0.62, 1, 0.55, 0.62),
    _CloudLayer(0.52, 0.9, 2, 0.8, 0.35),
    _CloudLayer(0.52, 0.9, 2, 0.8, 0.85),
    _CloudLayer(0.84, 1.3, 3, 1, 0.05),
    _CloudLayer(0.84, 1.3, 3, 1, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ).createShader(rect),
    );

    if (palette.glow.a > 0.01) {
      final center = Offset(size.width * 0.84, size.height * 0.2);
      final radius = size.shortestSide * 0.55;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [palette.glow, palette.glow.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = palette.arc;
    final arcCenter = Offset(size.width * 0.82, size.height * 1.02);
    for (var i = 0; i < 3; i++) {
      arcPaint.strokeWidth = 3.2 - i * 0.8;
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: size.width * (0.3 + i * 0.1)),
        3.4,
        2.1,
        false,
        arcPaint,
      );
    }

    final t = progress.value;
    final path = AppSky.cloudPath();
    for (final layer in _layers) {
      final span = size.width + 260 * layer.scale;
      final x = ((layer.phase + t * layer.speed) % 1.0) * span - 130 * layer.scale;
      final y = size.height * layer.y;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(layer.scale);
      canvas.drawPath(path.shift(const Offset(0, 4)), Paint()..color = palette.shade.withValues(alpha: layer.alpha * 0.55));
      canvas.drawPath(path, Paint()..color = palette.cloud.withValues(alpha: palette.cloud.a * layer.alpha));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.palette != palette;
}

class SkyScene extends StatefulWidget {
  const SkyScene({
    super.key,
    required this.mood,
    required this.child,
    this.borderRadius,
    this.forceLight = false,
    this.animate = true,
  });

  final SkyMood mood;
  final Widget child;
  final BorderRadius? borderRadius;
  final bool forceLight;
  final bool animate;

  @override
  State<SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<SkyScene> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 90));
  late final AnimationController _fade = AnimationController(vsync: this, duration: AppMotion.slow, value: 1);
  SkyPalette? _from;
  SkyPalette? _to;
  SkyMood? _mood;
  Brightness? _brightness;

  @override
  void dispose() {
    _drift.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool get _moving => widget.animate && !MotionPrefs.reduce && widget.mood != SkyMood.overcast;

  void _sync(Brightness brightness) {
    final target = AppSky.of(widget.mood, brightness);
    if (_to == null) {
      _from = target;
      _to = target;
    } else if (_mood != widget.mood || _brightness != brightness) {
      _from = SkyPalette.lerp(_from!, _to!, _fade.value);
      _to = target;
      _fade.forward(from: 0);
    }
    _mood = widget.mood;
    _brightness = brightness;
    if (_moving) {
      if (!_drift.isAnimating) _drift.repeat();
    } else if (_drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.forceLight ? Brightness.light : Theme.of(context).brightness;
    _sync(brightness);
    final from = _from!;
    final to = _to!;
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, child) {
            final palette = SkyPalette.lerp(from, to, Curves.easeOutCubic.transform(_fade.value));
            return CustomPaint(
              painter: _SkyPainter(palette: palette, repaint: _drift, progress: _drift),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class HorizonLine extends StatelessWidget {
  const HorizonLine({super.key, this.height = 1.5});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentBlue.withValues(alpha: 0),
            AppColors.accentBlue.withValues(alpha: 0.7),
            AppColors.primaryBlue.withValues(alpha: 0.5),
            AppColors.accentBlue.withValues(alpha: 0),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ),
      ),
    );
  }
}

class CloudBadge extends StatelessWidget {
  const CloudBadge({super.key, required this.icon, this.size = 104});

  final Widget icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(
        painter: _BadgePainter(fill: p.surfaceAlt, shade: p.border.withValues(alpha: 0.6)),
        child: Align(alignment: const Alignment(0, 0.18), child: icon),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.fill, required this.shade});

  final Color fill;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final path = AppSky.cloudPath();
    final scale = size.width / 150;
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.62);
    canvas.scale(scale);
    canvas.drawPath(path.shift(const Offset(0, 5)), Paint()..color = shade);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) => old.fill != fill || old.shade != shade;
}
