import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/empty_state.dart';

final logsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(trafficRepositoryProvider).logs(),
);

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final async = ref.watch(logsProvider);
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('set_logs')),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(logsProvider),
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: '$e', retryLabel: t.t('retry'), onRetry: () => ref.invalidate(logsProvider)),
        data: (lines) {
          if (lines.isEmpty) {
            return EmptyState(icon: FontAwesomeIcons.fileLines, title: t.t('logs_empty'), body: '');
          }
          final reversed = lines.reversed.toList();
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: reversed.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SelectableText(reversed[i], style: AppText.mono(p, size: 11)),
            ),
          );
        },
      ),
    );
  }
}
