import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

/// Play modes of the explore feed. Every mode maps to a base tag query
/// (always starting from `order:random`) which the user can freely edit;
/// gacha and quiz additionally toggle client-side cosmetics.
enum ExploreMode {
  random,
  hallOfFame,
  timeMachine,
  hiddenGems,
  motion,
  species,
  gacha,
  quiz;

  String get label => switch (this) {
    ExploreMode.random => 'Browse randomly'.tr,
    ExploreMode.hallOfFame => 'Hall of Fame'.tr,
    ExploreMode.timeMachine => 'Time Machine'.tr,
    ExploreMode.hiddenGems => 'Hidden Gems'.tr,
    ExploreMode.motion => 'Motion only'.tr,
    ExploreMode.species => 'Species slot'.tr,
    ExploreMode.gacha => 'Gacha roll'.tr,
    ExploreMode.quiz => 'Artist quiz'.tr,
  };

  String get description => switch (this) {
    ExploreMode.random => 'A random stream of the whole site'.tr,
    ExploreMode.hallOfFame => 'Only the highest scored posts'.tr,
    ExploreMode.timeMachine => 'Random posts from a bygone era'.tr,
    ExploreMode.hiddenGems => 'Unnoticed posts waiting to be found'.tr,
    ExploreMode.motion => 'Animated loops and short clips only'.tr,
    ExploreMode.species => 'Spin the slot and wander one species'.tr,
    ExploreMode.gacha => 'Every thumbnail stays blurred until revealed'.tr,
    ExploreMode.quiz => 'The artist is hidden; can you tell?'.tr,
  };

  IconData get icon => switch (this) {
    ExploreMode.random => Icons.shuffle_outlined,
    ExploreMode.hallOfFame => Icons.emoji_events_outlined,
    ExploreMode.timeMachine => Icons.history_edu_outlined,
    ExploreMode.hiddenGems => Icons.diamond_outlined,
    ExploreMode.motion => Icons.animation_outlined,
    ExploreMode.species => Icons.pets_outlined,
    ExploreMode.gacha => Icons.blur_on_outlined,
    ExploreMode.quiz => Icons.quiz_outlined,
  };

  /// The base tag query of the mode, with the currently locked [species]
  /// (species mode only) folded in.
  String tags({String? species}) => switch (this) {
    ExploreMode.species when species != null => 'order:random species:$species',
    _ => 'order:random',
  };
}

/// Curated species tags for the slot machine, in flicker order.
const List<String> kExploreSpecies = [
  'canine',
  'feline',
  'dragon',
  'equine',
  'avian',
  'reptile',
  'amphibian',
  'marsupial',
  'rodent',
  'lagomorph',
  'mustelid',
  'ursid',
  'bovid',
  'cervid',
  'cetacean',
  'insect',
  'arachnid',
  'alien',
  'human',
];
