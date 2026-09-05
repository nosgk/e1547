import 'dart:ui' show ImageFilter;

import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

/// State of the explore page's cosmetic play modes (gacha blur, artist
/// quiz). A singleton because the effects reach into pushed pages (the
/// post detail page) that sit outside the explore page's providers. It is
/// reset when the explore page is disposed.
class ExploreCosmetics extends ChangeNotifier {
  ExploreCosmetics._();

  static final ExploreCosmetics instance = ExploreCosmetics._();

  bool gacha = false;
  bool quiz = false;

  final Set<int> revealedPosts = {};
  final Set<String> revealedArtists = {};

  void setMode({required bool gacha, required bool quiz}) {
    if (gacha == this.gacha && quiz == this.quiz) return;
    this.gacha = gacha;
    this.quiz = quiz;
    reset();
  }

  void reset() {
    revealedPosts.clear();
    revealedArtists.clear();
    notifyListeners();
  }

  void revealPost(int id) {
    if (revealedPosts.add(id)) notifyListeners();
  }

  void revealArtists(Iterable<String> names) {
    if (names.every(revealedArtists.contains)) return;
    revealedArtists.addAll(names);
    notifyListeners();
  }
}

/// Blurs a post thumbnail until it is revealed: the first tap lifts the
/// blur (gacha roll), the next tap opens the post. Inert outside the
/// explore page's gacha mode.
class GachaGuard extends StatelessWidget {
  const GachaGuard({super.key, required this.post, required this.child});

  final Post post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ExploreCosmetics.instance,
      builder: (context, child) {
        final cosmetics = ExploreCosmetics.instance;
        if (!cosmetics.gacha || cosmetics.revealedPosts.contains(post.id)) {
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
                onTap: () => cosmetics.revealPost(post.id),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// Hides the artist of a post until revealed (artist quiz). Inert outside
/// the explore page's quiz mode. [names] are the artist tags of the post;
/// revealing also lifts the blur from tag chips keyed by those names.
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
    return AnimatedBuilder(
      animation: ExploreCosmetics.instance,
      builder: (context, child) {
        final cosmetics = ExploreCosmetics.instance;
        final revealed =
            cosmetics.revealedPosts.contains(post.id) ||
            names.isNotEmpty && names.every(cosmetics.revealedArtists.contains);
        if (!cosmetics.quiz || names.isEmpty || revealed) return child!;
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
                  cosmetics.revealPost(post.id);
                  cosmetics.revealArtists(names);
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
