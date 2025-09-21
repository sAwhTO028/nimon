import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';
import 'features/story/story_detail_screen.dart';
import 'features/writer/writer_screen.dart';

void main() => runApp(const NimonApp());

class NimonApp extends StatelessWidget {
  const NimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIMON',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
      routes: {
        StoryDetailScreen.routeName: (c) {
          final args =
          ModalRoute.of(c)!.settings.arguments as StoryDetailArgs;
          return StoryDetailScreen(storyId: args.storyId);
        },
        WriterScreen.routeName: (c) {
          final args = ModalRoute.of(c)!.settings.arguments as WriterArgs;
          return WriterScreen(storyId: args.storyId);
        },
      },
    );
  }
}
