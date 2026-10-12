import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';

class SkyNavItem {
  const SkyNavItem({required this.icon, required this.label, this.badge = 0});

  final IconData icon;
  final String label;
  final int badge;
}

class SkyNavBar extends StatelessWidget {
  const SkyNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    required this.running,
    required this.busy,
    required this.onPower,
    required this.powerLabel,
  });

  final List<SkyNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final bool running;
  final bool busy;
  final VoidCallback onPower;
  final String powerLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final left = items.sublist(0, 2);
    final right = items.sublist(2, 4);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 10),
        child: SizedBox(
          height: AppSpacing.navHeight + 6,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: AppSpacing.navHeight,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: p.surfaceAlt, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < left.length; i++)
                      Expanded(child: _NavButton(item: left[i], active: index == i, onTap: () => onChanged(i))),
                    const SizedBox(width: 74),
                    for (var i = 0; i < right.length; i++)
                      Expanded(
                        child: _NavButton(item: right[i], active: index == i + 2, onTap: () => onChanged(i + 2)),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -6,
                child: _PowerButton(running: running, busy: busy, onTap: onPower, label: powerLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final SkyNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = active ? AppColors.primaryBlue : p.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            width: active ? 22 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              gradient: AppComponents.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: active ? 1.14 : 1,
                duration: AppMotion.base,
                curve: AppMotion.curve,
                child: FaIcon(item.icon, size: 18, color: color),
              ),
              if (item.badge > 0)
                Positioned(
                  right: -10,
                  top: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${item.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: AppText.label(p).copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.running, required this.busy, required this.onTap, required this.label});

  final bool running;
  final bool busy;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final core = AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: running
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentBlue, AppColors.primaryBlue],
              )
            : null,
        color: running ? null : p.surfaceAlt,
        boxShadow: running ? AppComponents.softShadow(p) : null,
      ),
      alignment: Alignment.center,
      child: busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: running ? AppColors.cloudWhite : AppColors.primaryBlue,
              ),
            )
          : FaIcon(
              FontAwesomeIcons.powerOff,
              size: 22,
              color: running ? AppColors.cloudWhite : AppColors.primaryBlue,
            ),
    );

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.surface,
            border: Border.all(color: p.surfaceAlt, width: 0.8),
            boxShadow: [
              BoxShadow(color: p.shadow.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (running)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentBlue, width: 2),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25), duration: 1400.ms, curve: Curves.easeOut)
                    .fade(begin: 0.6, end: 0, duration: 1400.ms),
              core,
            ],
          ),
        ),
      ),
    );
  }
}
