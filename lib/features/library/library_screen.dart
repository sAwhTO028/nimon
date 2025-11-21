import 'package:flutter/material.dart';
import 'widgets/following_writers_section.dart';

/// Library screen showing user's saved content and following writers
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Following writers section at the top
              const FollowingWritersSection(),
              
              // Placeholder for future sections (saved stories, history, etc.)
              // Additional sections can be added here later
            ],
          ),
        ),
      ),
    );
  }
}
