import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/app_info.dart';
import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/animated_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';
import 'certificate_screen.dart';

final diagnosticsProvider = FutureProvider.autoDispose<List<DiagnosticItem>>(
  (ref) => ref.watch(trafficRepositoryProvider).diagnostics(),
);

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  Color _color(String level) {
    switch (level) {
      case 'ok':
        return AppColors.successGreen;
      case 'warn':
        return AppColors.warningAmber;
      case 'error':
        return AppColors.errorRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _icon(String level) {
    switch (level) {
      case 'ok':
        return FontAwesomeIcons.circleCheck;
      case 'warn':
      case 'error':
        return FontAwesomeIcons.circleExclamation;
      default:
        return FontAwesomeIcons.circleInfo;
    }
  }

  String? _fixTarget(DiagnosticItem item) {
    if (item.level != 'warn' && item.level != 'error') return null;
    switch (item.id) {
      case 'battery':
        return 'battery';
      case 'othervpn':
        return 'vpn';
      case 'notifications':
        return 'app';
      case 'internet':
        return 'network';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final async = ref.watch(diagnosticsProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('diag_title')),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(diagnosticsProvider),
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
          ),
        ],
      ),
      body: async.when(
        loading: () => const ShimmerList(count: 6),
        error: (e, _) => ErrorState(message: '$e', retryLabel: t.t('retry'), onRetry: () => ref.invalidate(diagnosticsProvider)),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, i) {
            final item = items[i];
            final color = _color(item.level);
            final target = _fixTarget(item);
            final isCert = item.id == 'ca' && item.level != 'ok';
            final actionable = target != null || isCert;
            return AnimatedCard(
              index: i,
              onTap: !actionable
                  ? null
                  : () {
                      if (isCert) {
                        Navigator.of(context).push(SlideFromRightRoute<void>(builder: (_) => const CertificateScreen()));
                      } else {
                        ref.read(trafficRepositoryProvider).openSettings(target!);
                      }
                    },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: FaIcon(_icon(item.level), size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.t('diag_${item.id}'), style: AppText.heading(p).copyWith(fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(
                          item.id == 'sdk' ? 'Android API ${item.value}' : t.t('diag_${item.id}_${item.value}'),
                          style: AppText.caption(p).copyWith(fontSize: 12.5),
                        ),
                        if (actionable) ...[
                          const SizedBox(height: 6),
                          Text(t.t('diag_fix'), style: AppText.label(p).copyWith(color: AppColors.primaryBlue)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
