import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/app_info.dart';
import '../providers/core_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_channel.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../utils/strings.dart';
import '../widgets/animated_card.dart';
import '../widgets/sky_button.dart';

class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  MonitorStatus _status = const MonitorStatus();
  Timer? _timer;
  bool _busy = false;
  int _urlIndex = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await ref.read(trafficRepositoryProvider).monitorStatus();
      if (mounted) setState(() => _status = s);
    } on ApiException {
      return;
    }
  }

  Future<void> _showPin(String pin) async {
    final t = ref.read(stringsProvider);
    await showScaleDialog<void>(
      context: context,
      dismissible: false,
      builder: (ctx) {
        final p = ctx.palette;
        return Center(
          child: Material(
            color: p.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(AppSpacing.page + 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('monitor_pin_dialog_title'), style: AppText.title(p)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
                    alignment: Alignment.center,
                    child: SelectableText(
                      pin.split('').join(' '),
                      style: AppText.mono(p, size: 28).copyWith(fontWeight: FontWeight.w700, color: p.brandStrong),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(t.t('monitor_pin_dialog_note'), style: AppText.caption(p).copyWith(fontSize: 12.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SkyButton(
                          label: t.t('copy'),
                          secondary: true,
                          icon: const FaIcon(FontAwesomeIcons.copy),
                          onPressed: () => Clipboard.setData(ClipboardData(text: pin)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: SkyButton(label: t.t('close'), onPressed: () => Navigator.of(ctx).pop())),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askPin() {
    final t = ref.read(stringsProvider);
    final controller = TextEditingController();
    return showScaleDialog<String>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Center(
            child: Material(
              color: p.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(AppSpacing.page + 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('monitor_pin_custom'), style: AppText.heading(p)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      style: AppText.mono(p, size: 20),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: AppComponents.input(p, hint: '4 - 6').copyWith(errorText: error),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.t('cancel'))),
                        TextButton(
                          onPressed: () {
                            final v = controller.text.trim();
                            if (v.length < 4 || v.length > 6) {
                              setLocal(() => error = t.t('monitor_pin_invalid'));
                              return;
                            }
                            Navigator.of(ctx).pop(v);
                          },
                          child: Text(t.t('save')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _newPin({String? custom}) async {
    final repo = ref.read(trafficRepositoryProvider);
    final pin = await repo.monitorSetPin(pin: custom);
    await ref.read(settingsProvider.notifier).load();
    if (!mounted) return;
    if (custom == null) await _showPin(pin);
    await _refresh();
  }

  Future<void> _toggle(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(trafficRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (value) {
        if (!_status.pinSet) await _newPin();
        await repo.monitorStart();
      } else {
        await repo.monitorStop();
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPort() async {
    final t = ref.read(stringsProvider);
    final current = ref.read(settingsProvider).settings.monitorPort;
    final controller = TextEditingController(text: '$current');
    final value = await showScaleDialog<String>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return Center(
          child: Material(
            color: p.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(AppSpacing.page + 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('monitor_port'), style: AppText.heading(p)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: AppText.mono(p, size: 16),
                    decoration: AppComponents.input(p, hint: '1024 - 65535'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.t('cancel'))),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: Text(t.t('save'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    final port = int.tryParse(value ?? '');
    if (port != null) {
      await ref.read(settingsProvider.notifier).update({'monitorPort': port});
      await _refresh();
    }
  }

  String _stateText(Strings t) {
    if (_status.running) return t.t('monitor_state_running');
    switch (_status.error) {
      case 'port_in_use':
        return t.t('monitor_state_port_in_use');
      case 'pin_not_set':
        return t.t('monitor_state_pin_not_set');
      case '':
        return t.t('monitor_state_stopped');
      default:
        return '${t.t('monitor_state_error')}: ${_status.error}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    final settings = ref.watch(settingsProvider).settings;
    final running = _status.running;
    final statusColor = running
        ? AppColors.successGreen
        : _status.error.isNotEmpty
            ? AppColors.errorRed
            : p.textSecondary;
    final urls = _status.urls;
    final selectedUrl = urls.isEmpty ? null : urls[_urlIndex.clamp(0, urls.length - 1)];

    return Scaffold(
      appBar: AppBar(title: Text(t.t('monitor_title'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AnimatedCard(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.t('monitor_enable'), style: AppText.heading(p))),
                    if (_busy)
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    else
                      Switch(value: running, onChanged: _toggle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_stateText(t), style: AppText.caption(p).copyWith(color: statusColor, fontSize: 13))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.t('monitor_intro'), style: AppText.caption(p).copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.inner + 2),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: FaIcon(FontAwesomeIcons.circleExclamation, size: 15, color: AppColors.warningAmber),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t.t('monitor_warn'), style: AppText.caption(p).copyWith(fontSize: 12.5))),
              ],
            ),
          ).fadeInUp(index: 1),
          if (running && selectedUrl != null) ...[
            const SizedBox(height: AppSpacing.cardGap),
            AnimatedCard(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('monitor_url'), style: AppText.label(p)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < urls.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      onTap: () => setState(() => _urlIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: i == _urlIndex ? p.surfaceAlt : Colors.transparent,
                          border: Border.all(color: p.surfaceAlt),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(urls[i], style: AppText.mono(p, size: 14))),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(ClipboardData(text: urls[i]));
                                messenger.showSnackBar(SnackBar(content: Text(t.t('copied')), duration: const Duration(seconds: 1)));
                              },
                              icon: const FaIcon(FontAwesomeIcons.copy, size: 14, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: QrImageView(data: selectedUrl, size: 180, backgroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text(t.t('monitor_scan'), style: AppText.label(p), textAlign: TextAlign.center)),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('${t.t('monitor_sessions')}: ${_status.sessions}', style: AppText.label(p)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.cardGap),
          AnimatedCard(
            index: 3,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.tight),
            child: Column(
              children: [
                InkWell(
                  onTap: running ? null : _editPort,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const SizedBox(width: 22, child: FaIcon(FontAwesomeIcons.globe, size: 15, color: AppColors.primaryBlue)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t.t('monitor_port'), style: AppText.body(p))),
                        Text('${settings.monitorPort}', style: AppText.mono(p, size: 13).copyWith(color: p.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 22, child: FaIcon(FontAwesomeIcons.key, size: 15, color: AppColors.primaryBlue)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t.t('monitor_pin'), style: AppText.body(p))),
                      Text(
                        _status.pinSet ? t.t('monitor_pin_set') : t.t('monitor_pin_none'),
                        style: AppText.caption(p),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: SkyButton(
                          label: t.t('monitor_pin_random'),
                          secondary: true,
                          icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                          onPressed: () => _newPin(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SkyButton(
                          label: t.t('monitor_pin_custom'),
                          secondary: true,
                          icon: const FaIcon(FontAwesomeIcons.pen),
                          onPressed: () async {
                            final pin = await _askPin();
                            if (pin != null) await _newPin(custom: pin);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    const SizedBox(width: 22, child: FaIcon(FontAwesomeIcons.powerOff, size: 15, color: AppColors.primaryBlue)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.t('monitor_stop_with_capture'), style: AppText.body(p))),
                    Switch(
                      value: settings.monitorStopWithCapture,
                      onChanged: (v) => ref.read(settingsProvider.notifier).update({'monitorStopWithCapture': v}),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
