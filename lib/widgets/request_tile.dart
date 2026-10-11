import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/traffic.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/format.dart';
import 'app_icon.dart';
import 'method_badge.dart';
import 'status_badge.dart';

class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.item, required this.onTap, this.onLongPress});

  final TrafficSummary item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rail = statusColor(item);
    final size = item.tunnel
        ? Fmt.bytes(item.responseSize + item.requestSize)
        : item.responseSize > 0
            ? Fmt.bytes(item.responseSize)
            : '-';
    return Container(
      decoration: AppComponents.card(p),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: rail),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.inner, AppSpacing.inner, AppSpacing.inner, AppSpacing.inner),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MethodBadge(method: item.method, compact: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.host,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.heading(p).copyWith(fontSize: 14),
                              ),
                            ),
                            if (item.modified) ...[
                              const FaIcon(FontAwesomeIcons.wandMagic, size: 12, color: AppColors.warningAmber),
                              const SizedBox(width: 8),
                            ],
                            StatusBadge.forTraffic(item),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.path.isEmpty ? '/' : item.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(p).copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            AppIcon(package: item.appPackage, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.appName.isEmpty ? '-' : item.appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.label(p),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FaIcon(FontAwesomeIcons.arrowDown, size: 9, color: p.textSecondary),
                            const SizedBox(width: 3),
                            Text(size, style: AppText.label(p)),
                            const SizedBox(width: 10),
                            FaIcon(FontAwesomeIcons.stopwatch, size: 9, color: p.textSecondary),
                            const SizedBox(width: 3),
                            Text(Fmt.duration(item.totalMs), style: AppText.label(p)),
                            const Spacer(),
                            Text(Fmt.clock(item.timestamp), style: AppText.label(p)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
