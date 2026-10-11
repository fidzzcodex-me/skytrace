import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/settings_provider.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/component_styles.dart';
import '../theme/text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/cert_guide.dart';
import '../widgets/sky_button.dart';
import '../widgets/trace_arc.dart';
import 'home_screen.dart';

const String _trustSnippet = '<network-security-config>\n'
    '  <debug-overrides>\n'
    '    <trust-anchors>\n'
    '      <certificates src="user" />\n'
    '    </trust-anchors>\n'
    '  </debug-overrides>\n'
    '</network-security-config>';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  static const int _count = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).update({'onboardingDone': true});
    if (!mounted) return;
    Navigator.of(context).pushReplacement(FadeRoute<void>(builder: (_) => const HomeScreen()));
  }

  void _next() {
    if (_page == _count - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: AppMotion.base, curve: AppMotion.curve);
  }

  void _previous() {
    _controller.previousPage(duration: AppMotion.base, curve: AppMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppComponents.skyBackground(p)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 0),
                child: Row(
                  children: [
                    const AppLogo(variant: LogoVariant.mark, height: 30),
                    const Spacer(),
                    TextButton(onPressed: _finish, child: Text(t.t('skip'))),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _WelcomePage(title: t.t('ob_welcome_title'), body: t.t('ob_welcome_body')),
                    _InfoPage(
                      icon: FontAwesomeIcons.shieldHalved,
                      title: t.t('ob_vpn_title'),
                      body: t.t('ob_vpn_body'),
                    ),
                    _ScrollPage(
                      icon: FontAwesomeIcons.certificate,
                      title: t.t('ob_cert_title'),
                      child: const CertGuide(showTrustNote: false),
                    ),
                    _ScrollPage(
                      icon: FontAwesomeIcons.mobileScreen,
                      title: t.t('ob_trust_title'),
                      child: _TrustPage(body: t.t('ob_trust_body'), copyLabel: t.t('copy'), copiedLabel: t.t('copied')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: _page == 0
                          ? const SizedBox.shrink()
                          : SkyButton(label: t.t('back'), secondary: true, onPressed: _previous),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _count; i++)
                            AnimatedContainer(
                              duration: AppMotion.fast,
                              curve: AppMotion.curve,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page ? AppColors.primaryBlue : AppColors.accentBlue.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: SkyButton(
                        label: _page == _count - 1 ? t.t('finish') : t.t('next'),
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      children: [
        const Positioned(top: 10, right: -60, child: TraceArc(size: 250, opacity: 0.25)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(variant: LogoVariant.vertical, height: 180, hero: false).scaleIn(),
                const SizedBox(height: 28),
                Text(title, style: AppText.title(p), textAlign: TextAlign.center).fadeInUp(index: 2),
                const SizedBox(height: 10),
                Text(body, style: AppText.body(p).copyWith(color: p.textSecondary), textAlign: TextAlign.center)
                    .fadeInUp(index: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: FaIcon(icon, size: 44, color: AppColors.primaryBlue),
            ).scaleIn(),
            const SizedBox(height: 28),
            Text(title, style: AppText.title(p), textAlign: TextAlign.center).fadeInUp(index: 2),
            const SizedBox(height: 10),
            Text(body, style: AppText.body(p).copyWith(color: p.textSecondary), textAlign: TextAlign.center)
                .fadeInUp(index: 3),
          ],
        ),
      ),
    );
  }
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: FaIcon(icon, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppText.title(p))),
            ],
          ).fadeInUp(),
          const SizedBox(height: AppSpacing.page),
          Container(
            padding: const EdgeInsets.all(AppSpacing.page),
            decoration: AppComponents.card(p),
            child: child,
          ).fadeInUp(index: 1),
        ],
      ),
    );
  }
}

class _TrustPage extends StatelessWidget {
  const _TrustPage({required this.body, required this.copyLabel, required this.copiedLabel});

  final String body;
  final String copyLabel;
  final String copiedLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: AppText.body(p)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.inner),
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
          child: SelectableText(_trustSnippet, style: AppText.mono(p, size: 11.5)),
        ),
        const SizedBox(height: 10),
        Text('res/xml/network_security_config.xml', style: AppText.label(p)),
        const SizedBox(height: 12),
        SkyButton(
          label: copyLabel,
          secondary: true,
          icon: const FaIcon(FontAwesomeIcons.copy),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(const ClipboardData(text: _trustSnippet));
            messenger.showSnackBar(SnackBar(content: Text(copiedLabel), duration: const Duration(seconds: 1)));
          },
        ),
      ],
    );
  }
}
