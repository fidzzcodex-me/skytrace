import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/component_styles.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.5 + 3 * t, -0.3),
              end: Alignment(-0.5 + 3 * t, 0.3),
              colors: [p.surfaceAlt, p.surface, p.surfaceAlt],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.softSky, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

class RequestTileSkeleton extends StatelessWidget {
  const RequestTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inner + 2),
      decoration: AppComponents.card(p),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 44, height: 18, radius: 8),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 14)),
              SizedBox(width: 10),
              SkeletonBox(width: 36, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: 10),
          SkeletonBox(width: 220, height: 11),
          SizedBox(height: 10),
          SkeletonBox(width: 150, height: 10),
        ],
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 7});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (_, __) => const RequestTileSkeleton(),
      ),
    );
  }
}
