import 'dart:ui' show ImageFilter;

import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

/// Revealed posts and artists of the gacha and quiz play modes.
/// Session-only: toggling a mode off clears its reveals.
class GameReveals extends ChangeNotifier {
  GameReveals._();

  static final GameReveals instance = GameReveals._();

  final Set<int> posts = {};
  final Set<String> artists = {};

  void revealPost(int id) {
    if (posts.add(id)) notifyListeners();
  }

  void revealArtists(Iterable<String> names) {
    if (names.every(artists.contains)) return;
    artists.addAll(names);
    notifyListeners();
  }

  void clearPosts() {
    posts.clear();
    notifyListeners();
  }

  void clearArtists() {
    artists.clear();
    notifyListeners();
  }
}

/// A tag-based play game: a fixed set of tag terms toggled onto the
/// home page's search query.
class PlayGame {
  const PlayGame(this.name, this.description, this.icon, this.terms);

  /// i18n key of the game's name.
  final String name;

  /// i18n key of a one-line description.
  final String description;
  final IconData icon;
  final List<String> terms;
}

const List<PlayGame> kPlayGames = [
  PlayGame(
    'Hall of Fame',
    'Only the highest scored posts',
    Icons.emoji_events_outlined,
    ['score:>=300'],
  ),
  PlayGame(
    'Time Machine',
    'Random posts from a bygone era',
    Icons.history_edu_outlined,
    ['date:<2014-01-01'],
  ),
  PlayGame(
    'Hidden Gems',
    'Unnoticed posts waiting to be found',
    Icons.diamond_outlined,
    ['score:<20', 'favcount:<5'],
  ),
  PlayGame(
    'Motion only',
    'Animated loops and short clips only',
    Icons.animation_outlined,
    ['~type:webm', '~type:gif'],
  ),
];

/// Home-drawer play modes (tag games, gacha, quiz, slot, slideshow).
/// Shared by Home, Hot, and Search so the same controls stay in sync.
class PostPlayModes extends StatelessWidget {
  const PostPlayModes({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = SearchTools(context.watch<PostParamsController>());
    final settings = context.watch<Settings>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Play modes'.tr,
        ),
        for (final game in kPlayGames)
          SwitchListTile(
            secondary: Icon(game.icon),
            title: Text(game.name.tr),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.description.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: dimTextColor(context),
                  ),
                ),
                Text(
                  game.terms.join(' '),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
            value: tools.hasTokens(game.terms),
            onChanged: (_) => tools.toggleTokens(game.terms),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: settings.gameGacha,
          builder: (context, value, child) => SwitchListTile(
            secondary: const Icon(Icons.blur_on_outlined),
            title: Text('Gacha roll'.tr),
            subtitle: Text('Every thumbnail stays blurred until revealed'.tr),
            value: value,
            onChanged: (value) {
              settings.gameGacha.value = value;
              if (!value) GameReveals.instance.clearPosts();
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: settings.gameQuiz,
          builder: (context, value, child) => SwitchListTile(
            secondary: const Icon(Icons.quiz_outlined),
            title: Text('Artist quiz'.tr),
            subtitle: Text('The artist is hidden; can you tell?'.tr),
            value: value,
            onChanged: (value) {
              settings.gameQuiz.value = value;
              if (!value) GameReveals.instance.clearArtists();
            },
          ),
        ),
        Builder(
          builder: (context) {
            final slotTag = settings.slotTag.value;
            return ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: Text('Universal slot'.tr),
              subtitle: slotTag.isEmpty
                  ? Text('Roll a random tag from a chosen category'.tr)
                  : Text(
                      slotTag,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
              trailing: slotTag.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear slot tag'.tr,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => tools.clearSlotTag(settings),
                    ),
              onTap: () async {
                final tag = await showTagSlotDialog(
                  context,
                  tags: context.read<Client>().tags,
                );
                if (tag != null && context.mounted) {
                  tools.swapSlotTag(tag, settings);
                }
              },
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.slideshow_outlined),
          title: Text('Zen slideshow'.tr),
          subtitle: Text('Fullscreen auto-advancing show'.tr),
          onTap: () {
            Navigator.of(context).pop();
            showSlideshowPicker(context, initialTags: tools.tags);
          },
        ),
      ],
    );
  }
}

/// Blurs a post thumbnail until it is revealed: the first tap lifts the
/// blur, the next tap opens the post. Inert unless the gacha play mode is
/// enabled in the settings.
class GachaGuard extends StatelessWidget {
  const GachaGuard({super.key, required this.post, required this.child});

  final Post post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = trySettingsOf(context);
    if (settings == null) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([GameReveals.instance, settings.gameGacha]),
      builder: (context, child) {
        if (!settings.gameGacha.value ||
            GameReveals.instance.posts.contains(post.id)) {
          return child!;
        }
        return Stack(
          fit: StackFit.passthrough,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: child,
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to reveal'.tr,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => GameReveals.instance.revealPost(post.id),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// Hides the artist of a post until revealed. Inert unless the quiz play
/// mode is enabled in the settings. Revealing a post also lifts the blur
/// from tag chips keyed by its artist names.
class QuizGuard extends StatelessWidget {
  const QuizGuard({
    super.key,
    required this.post,
    required this.names,
    required this.child,
  });

  final Post post;
  final List<String> names;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = trySettingsOf(context);
    if (settings == null) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([GameReveals.instance, settings.gameQuiz]),
      builder: (context, child) {
        final reveals = GameReveals.instance;
        final revealed =
            reveals.posts.contains(post.id) ||
            names.isNotEmpty && names.every(reveals.artists.contains);
        if (!settings.gameQuiz.value || names.isEmpty || revealed) {
          return child!;
        }
        return Stack(
          fit: StackFit.passthrough,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: child,
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  reveals.revealPost(post.id);
                  reveals.revealArtists(names);
                },
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Guess the artist'.tr,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
