import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/theme/colors.dart';
import 'package:skytrace/theme/sky.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('text stays readable on every sky mood', () {
    for (final brightness in Brightness.values) {
      final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
      for (final mood in SkyMood.values) {
        test('${brightness.name} ${mood.name}', () {
          final sky = AppSky.of(mood, brightness);
          expect(contrast(palette.textPrimary, sky.top), greaterThanOrEqualTo(4.5));
          expect(contrast(palette.textPrimary, sky.bottom), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  group('secondary text meets AA', () {
    test('light surfaces', () {
      expect(contrast(AppPalette.light.textSecondary, AppPalette.light.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(AppPalette.light.textSecondary, AppPalette.light.surfaceAlt), greaterThanOrEqualTo(4.5));
    });

    test('dark surfaces', () {
      expect(contrast(AppPalette.dark.textSecondary, AppPalette.dark.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(AppPalette.dark.textSecondary, AppPalette.dark.surfaceAlt), greaterThanOrEqualTo(4.5));
    });

    test('link and button text uses the deep blue', () {
      expect(contrast(AppPalette.light.brandStrong, AppPalette.light.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('SkyPalette', () {
    test('lerp returns the endpoints', () {
      final a = AppSky.of(SkyMood.overcast, Brightness.light);
      final b = AppSky.of(SkyMood.clear, Brightness.light);
      expect(SkyPalette.lerp(a, b, 0).top, a.top);
      expect(SkyPalette.lerp(a, b, 1).top, b.top);
    });
  });

  testWidgets('SkyScene renders its child and survives mood changes', (tester) async {
    Widget build(SkyMood mood) => MaterialApp(
          home: Scaffold(
            body: SkyScene(mood: mood, child: const Center(child: Text('hello'))),
          ),
        );

    await tester.pumpWidget(build(SkyMood.overcast));
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(build(SkyMood.clear));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(build(SkyMood.dusk));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
