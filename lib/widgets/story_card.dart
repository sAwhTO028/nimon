import 'package:flutter/material.dart';
import 'package:nimon/models/story.dart';

class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  const StoryCard({super.key, required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 28, child: Text(story.level, style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(story.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(story.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 12),
              Row(children: [
                const Icon(Icons.favorite, size: 18, color: Colors.pink),
                const SizedBox(width: 4),
                Text('${story.likes}')
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
