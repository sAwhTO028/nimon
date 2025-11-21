import 'package:flutter/material.dart';
import '../../models/following_writer.dart';
import '../../data/following_repository.dart';

/// Screen showing all following writers in a list
class FollowingWritersScreen extends StatelessWidget {
  const FollowingWritersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following Writers'),
      ),
      body: FutureBuilder<List<FollowingWriter>>(
        future: followingRepo.fetchFollowingWriters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading writers: ${snapshot.error}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            );
          }

          final writers = snapshot.data ?? [];

          if (writers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You're not following any writers yet.",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: writers.length,
            itemBuilder: (context, index) {
              final writer = writers[index];
              return _WriterListItem(writer: writer);
            },
          );
        },
      ),
    );
  }
}

/// List item for a writer
class _WriterListItem extends StatelessWidget {
  final FollowingWriter writer;

  const _WriterListItem({required this.writer});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        backgroundImage: writer.avatarUrl != null
            ? NetworkImage(writer.avatarUrl!)
            : null,
        child: writer.avatarUrl == null
            ? Text(
                writer.initial,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : null,
      ),
      title: Text(writer.name),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: () {
        // TODO: Navigate to writer profile when implemented
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${writer.name} profile (coming soon)')),
        );
      },
    );
  }
}

