import 'package:duanju_app/app_bottom_navigation.dart';
import 'package:duanju_app/app_theme.dart';
import 'package:duanju_app/liquid_glass.dart';
import 'package:duanju_app/liquid_tab_bar.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
  }

  testWidgets('liquid tab bar selects by tap and by dragging the lens', (
    tester,
  ) async {
    phone(tester);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.iosLight,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            extendBody: true,
            bottomNavigationBar: LiquidTabBar(
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
              items: const [
                LiquidTabItem(icon: LucideIcons.compass, label: '发现'),
                LiquidTabItem(icon: LucideIcons.bookmark, label: '追剧'),
                LiquidTabItem(icon: LucideIcons.history, label: '最近观看'),
                LiquidTabItem(icon: LucideIcons.arrowDownToLine, label: '下载'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(LiquidTabBar));
    expect(bar.bottom, 844);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(selected, 2);
    final item = tester.getSize(find.byKey(const ValueKey('bottom-nav-2')));
    expect(item.height, greaterThanOrEqualTo(44));
    await tester.drag(
      find.byKey(const ValueKey('bottom-nav-2')),
      Offset(-item.width * 2.2, 0),
    );
    await tester.pumpAndSettle();
    expect(selected, 0);
    await tester.drag(
      find.byKey(const ValueKey('bottom-nav-0')),
      Offset(item.width * 3.2, 0),
    );
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS builds the glass shell while Android keeps its navigation', (
    tester,
  ) async {
    phone(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      DuanjuApp(repository: FixtureRepository(), store: store),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsNothing);
    expect(find.byType(GlassButtonGroup), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('我的追剧'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;

    await tester.pumpWidget(
      DuanjuApp(repository: FixtureRepository(), store: store),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsNothing);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
