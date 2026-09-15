import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_tracker/features/dashboard/presentation/more_tab.dart';

void main() {
  Widget buildRouted() {
    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(path: '/more', builder: (context, state) => const MoreTab()),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile screen')),
        ),
        GoRoute(
          path: '/body',
          builder: (context, state) => const Scaffold(body: Text('Body screen')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('lists every remaining feature and Settings', (tester) async {
    await pumpTallSurface(tester, buildRouted());

    expect(find.text('Body composition'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Adherence'), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Meal planning'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Settings navigates to the Profile screen', (tester) async {
    await pumpTallSurface(tester, buildRouted());

    await tester.tap(find.byKey(const Key('moreNavRow_Settings')));
    await tester.pumpAndSettle();

    expect(find.text('Profile screen'), findsOneWidget);
  });

  testWidgets('tapping Body composition navigates there', (tester) async {
    await pumpTallSurface(tester, buildRouted());

    await tester.tap(find.byKey(const Key('moreNavRow_Body composition')));
    await tester.pumpAndSettle();

    expect(find.text('Body screen'), findsOneWidget);
  });
}
