import 'package:flutter/material.dart';
import 'package:nimon/core/responsive.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/features/writer/writer_screen.dart';

class StoryDetailArgs {
  final String storyId;
  StoryDetailArgs(this.storyId);
}

class StoryDetailScreen extends StatefulWidget {
  static const routeName = '/storyDetail';

  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  // don’t type-hint to interface to avoid signature mismatches
  final _repo = StoryRepoMock();

  late Future<Story?> _fStory;
  late Future<List<Episode>> _fEpisodes;

  @override
  void initState() {
    super.initState();
    // ရှိပြီးသား mock API မတည့်နိုင်လို့ fallback လုပ်ပေးထားတယ်
    _fStory = _loadStory(widget.storyId);
    _fEpisodes = _loadEpisodes(widget.storyId);
  }

  Future<Story?> _loadStory(String id) async {
    try {
      // repo.getStoryById ဆိုတာရှိရင် သုံး
      // ignore: avoid_dynamic_calls
      final hasGetById =
          _repo.runtimeType.toString().contains('StoryRepoMock') &&
              _repo
                  .toString()
                  .contains('getStoryById'); // best-effort (safe for mock)
      if (hasGetById) {
        // @ts-ignore-ish
        // ignore: invalid_use_of_protected_member
        return await (_repo as dynamic).getStoryById(id);
      }
    } catch (_) {}
    // မရှိရင် listStories ထဲကနေ ရှာ
    final stories = await (_repo as dynamic).listStories();
    return (stories as List<Story>).firstWhere((s) => s.id == id);
  }

  Future<List<Episode>> _loadEpisodes(String storyId) async {
    try {
      // getEpisodesByStory ရှိရင်
      // ignore: invalid_use_of_protected_member
      return await (_repo as dynamic).getEpisodesByStory(storyId);
    } catch (_) {
      // မရှိရင် listEpisodes
      // ignore: invalid_use_of_protected_member
      return await (_repo as dynamic).listEpisodes(storyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = R.hPad(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
        actions: [
          IconButton(
            tooltip: 'Edit+',
            onPressed: () => Navigator.pushNamed(
              context,
              WriterScreen.routeName,
              arguments: WriterArgs(widget.storyId),
            ),
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 12).add(pad),
        child: FutureBuilder(
          future: Future.wait([_fStory, _fEpisodes]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final story = snap.data![0] as Story?;
            final eps = snap.data![1] as List<Episode>;
            if (story == null) {
              return const Center(child: Text('Story not found'));
            }

            return LayoutBuilder(
              builder: (c, cons) {
                final isWide = cons.maxWidth >= 720;
                final header = _Header(story: story, episodes: eps.length);
                final list = _EpisodeList(eps: eps);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(flex: 5, child: header),
                      const SizedBox(width: 24),
                      Flexible(flex: 6, child: list),
                    ],
                  );
                }
                return ListView(
                  children: [
                    header,
                    const SizedBox(height: 16),
                    list,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Story story;
  final int episodes;
  const _Header({required this.story, required this.episodes});

  @override
  Widget build(BuildContext context) {
    final radius = R.radius(context);
    final cover = (story.coverUrl?.isNotEmpty ?? false)
        ? story.coverUrl!
        : 'https://placehold.co/600x800/png';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: R.maxTextWidth(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(cover, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story.title,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text('Level ${story.level}'),
                              visualDensity: VisualDensity.compact,
                              side: const BorderSide(color: Colors.black12),
                            ),
                            Chip(
                              label: Text('$episodes eps'),
                              visualDensity: VisualDensity.compact,
                              side: const BorderSide(color: Colors.black12),
                            ),
                            if ((story.tags ?? []).isNotEmpty)
                              ...story.tags!.take(3).map((t) => Chip(
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(
                                    color: Colors.black12),
                              )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                story.description ?? '—',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeList extends StatelessWidget {
  final List<Episode> eps;
  const _EpisodeList({required this.eps});

  @override
  Widget build(BuildContext context) {
    final radius = R.radius(context);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) {
        final e = eps[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: ListTile(
            title: Text('Episode ${e.index}'),
            subtitle: Text(
              e.preview ?? e.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        );
      },
    );
  }
}
