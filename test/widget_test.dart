import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/theme/app_theme.dart';
import 'package:skytrace/theme/colors.dart';
import 'package:skytrace/utils/strings.dart';
import 'package:skytrace/widgets/empty_state.dart';
import 'package:skytrace/widgets/method_badge.dart';
import 'package:skytrace/widgets/status_badge.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Widget host(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));
}

void main() {
  testWidgets('MethodBadge shows the uppercase method', (tester) async {
    await tester.pumpWidget(host(const MethodBadge(method: 'post')));
    expect(find.text('POST'), findsOneWidget);
  });

  testWidgets('StatusBadge renders its label', (tester) async {
    await tester.pumpWidget(host(const StatusBadge(label: '404', color: AppColors.warningAmber)));
    expect(find.text('404'), findsOneWidget);
  });

  testWidgets('EmptyState shows title and body', (tester) async {
    await tester.pumpWidget(
      host(const EmptyState(icon: FontAwesomeIcons.globe, title: 'Nothing here', body: 'Start capture')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Start capture'), findsOneWidget);
  });

  test('palette extension is registered on both themes', () {
    expect(AppTheme.light.extension<AppPalette>(), isNotNull);
    expect(AppTheme.dark.extension<AppPalette>(), isNotNull);
  });

  test('strings resolve in both languages and fall back to the key', () {
    expect(const Strings('en').t('nav_home'), 'Home');
    expect(const Strings('id').t('nav_home'), 'Beranda');
    expect(const Strings('en').t('missing_key'), 'missing_key');
  });
}
