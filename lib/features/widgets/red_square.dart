import 'package:flutter/material.dart';
import '../writer/writer_screen.dart';

class RedSquare extends StatelessWidget {
  const RedSquare({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const _TargetScreen(),
          transitionsBuilder: (c, anim, a2, child) {
            final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween(begin: const Offset(1,0), end: Offset.zero).animate(curve),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ));
      },
      child: Container(width: 56, height: 56, color: Colors.red),
    );
  }
}

class _TargetScreen extends StatelessWidget {
  const _TargetScreen();
  @override
  Widget build(BuildContext context) {
    // demo: jump to writer with a dummy story id
    return const WriterScreen(storyId: '1');
  }
}
