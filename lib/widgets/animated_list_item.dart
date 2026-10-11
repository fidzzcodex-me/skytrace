import 'package:flutter/material.dart';

import '../theme/animations.dart';

class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({super.key, required this.index, required this.child, this.enabled = true});

  final int index;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child.fadeInUp(index: index);
  }
}
