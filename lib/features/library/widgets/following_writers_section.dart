import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/following_writer.dart';
import '../../../data/following_repository.dart';

/// Horizontal scrollable row showing following writers
class FollowingWritersSection extends StatelessWidget {
  const FollowingWritersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FollowingWriter>>(
      future: followingRepo.fetchFollowingWriters(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final writers = snapshot.data ?? [];

        if (writers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              "You're not following any writers yet.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          );
        }

        // Show first 14 writers + "All" button if more than 14
        final displayWriters = writers.length > 14
            ? writers.take(14).toList()
            : writers;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Following writers',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: displayWriters.length + 1, // +1 for "All" button
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == displayWriters.length) {
                      // "All" button at the end
                      return _AllWritersButton();
                    }
                    return _WriterAvatar(
                      writer: displayWriters[index],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Individual writer avatar item
class _WriterAvatar extends StatelessWidget {
  final FollowingWriter writer;

  const _WriterAvatar({required this.writer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to writer profile when implemented
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${writer.name} profile (coming soon)')),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            backgroundImage: writer.avatarUrl != null
                ? NetworkImage(writer.avatarUrl!)
                : null,
            child: writer.avatarUrl == null
                ? Text(
                    writer.initial,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              writer.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Colors.black87,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "All" button at the end of the row
class _AllWritersButton extends StatelessWidget {
  const _AllWritersButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/library/following-writers');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              color: Colors.transparent,
            ),
            child: Center(
              child: Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              'All',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

