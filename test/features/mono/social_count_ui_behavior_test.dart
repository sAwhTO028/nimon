import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/format_social_count.dart';

/// Mirrors optimistic react + likes and follow + followers updates without
/// pumping full Mono / public profile screens.
void main() {
  testWidgets('optimistic react updates visible likes label', (tester) async {
    await tester.pumpWidget(const _ReactCountHarness(initialLikes: 2));

    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reactTap')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reactTap')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('optimistic follow updates formatted followers', (tester) async {
    await tester.pumpWidget(const _FollowersHarness(initialFollowers: 999));

    expect(find.text(formatSocialCount(999)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('followTap')));
    await tester.pump();
    expect(find.text(formatSocialCount(1000)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('followTap')));
    await tester.pump();
    expect(find.text(formatSocialCount(999)), findsOneWidget);
  });
}

class _ReactCountHarness extends StatefulWidget {
  const _ReactCountHarness({required this.initialLikes});

  final int initialLikes;

  @override
  State<_ReactCountHarness> createState() => _ReactCountHarnessState();
}

class _ReactCountHarnessState extends State<_ReactCountHarness> {
  late int _likes;
  bool _reacted = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
  }

  void _toggle() {
    setState(() {
      final next = !_reacted;
      _likes += next ? 1 : -1;
      if (_likes < 0) _likes = 0;
      _reacted = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          key: const ValueKey('reactTap'),
          onTap: _toggle,
          child: Center(
            child: Text(monoReactRailPrimaryLabel(_likes)),
          ),
        ),
      ),
    );
  }
}

class _FollowersHarness extends StatefulWidget {
  const _FollowersHarness({required this.initialFollowers});

  final int initialFollowers;

  @override
  State<_FollowersHarness> createState() => _FollowersHarnessState();
}

class _FollowersHarnessState extends State<_FollowersHarness> {
  late int _followers;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _followers = widget.initialFollowers;
  }

  void _toggle() {
    setState(() {
      final next = !_following;
      _followers += next ? 1 : -1;
      if (_followers < 0) _followers = 0;
      _following = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          key: const ValueKey('followTap'),
          onTap: _toggle,
          child: Center(
            child: Text(formatSocialCount(_followers)),
          ),
        ),
      ),
    );
  }
}
