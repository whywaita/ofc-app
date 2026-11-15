import '../cards/playing_card.dart';
import '../rules/game_options.dart';
import 'hand_rank.dart';

/// Evaluates rows of cards under one [WildMode].
///
/// A wild card may stand for any real card not already in the row. Rather than encoding the best
/// use of wilds category by category, the evaluator enumerates every multiset of ranks the wilds
/// could take (at most 1,820 for four wilds) and evaluates each; suits only matter for a flush,
/// which needs the fixed cards to share one suit and all five ranks to differ. The same code path
/// serves deuces and jokers, and [candidates5] / [candidates3] expose every reachable hand so a
/// board can pick the strongest one that does not foul.
class HandEvaluator {
  const HandEvaluator(this.wildMode);

  final WildMode wildMode;

  Hand5Rank best5(List<PlayingCard> cards) => _max(candidates5(cards));

  Hand3Rank best3(List<PlayingCard> cards) => _max(candidates3(cards));

  /// Every distinct hand a five-card row can make.
  List<Hand5Rank> candidates5(List<PlayingCard> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Need 5 cards, got ${cards.length}');
    }
    final (fixed, wilds) = _split(cards);
    final ranks = [for (final c in fixed) c.rank.value];
    if (wilds == 0) {
      final flush = fixed.map((c) => c.suit).toSet().length == 1;
      return [_rank5(ranks, flush: flush, wild: false)];
    }
    final flushPossible = fixed.map((c) => c.suit).toSet().length <= 1;
    final out = <Hand5Rank>{};
    for (final extra in _rankMultisets(wilds)) {
      final all = [...ranks, ...extra];
      if (!_atMostFourOfEach(all)) continue;
      out.add(_rank5(all, flush: false, wild: true));
      if (flushPossible && all.toSet().length == 5) {
        out.add(_rank5(all, flush: true, wild: true));
      }
    }
    return out.toList();
  }

  /// Every distinct hand a three-card row can make.
  List<Hand3Rank> candidates3(List<PlayingCard> cards) {
    if (cards.length != 3) {
      throw ArgumentError('Need 3 cards, got ${cards.length}');
    }
    final (fixed, wilds) = _split(cards);
    final ranks = [for (final c in fixed) c.rank.value];
    if (wilds == 0) return [_rank3(ranks, wild: false)];
    return {
      for (final extra in _rankMultisets(wilds))
        _rank3([...ranks, ...extra], wild: true),
    }.toList();
  }

  (List<StandardCard>, int) _split(List<PlayingCard> cards) {
    final fixed = <StandardCard>[];
    var wilds = 0;
    for (final c in cards) {
      if (wildMode.isWild(c)) {
        wilds++;
      } else if (c is StandardCard) {
        fixed.add(c);
      } else {
        throw ArgumentError('$c is not wild under ${wildMode.name}');
      }
    }
    return (fixed, wilds);
  }
}

T _max<T extends Comparable<T>>(Iterable<T> xs) =>
    xs.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

/// Non-decreasing sequences of [k] rank values (2..14): each multiset once.
Iterable<List<int>> _rankMultisets(int k) sync* {
  final cur = <int>[];
  Iterable<List<int>> go(int from) sync* {
    if (cur.length == k) {
      yield List.of(cur);
      return;
    }
    for (var r = from; r <= 14; r++) {
      cur.add(r);
      yield* go(r);
      cur.removeLast();
    }
  }

  yield* go(2);
}

bool _atMostFourOfEach(List<int> ranks) {
  final counts = <int, int>{};
  for (final r in ranks) {
    if ((counts[r] = (counts[r] ?? 0) + 1) > 4) return false;
  }
  return true;
}

/// Ranks grouped by multiplicity: larger groups first, higher rank first within a size.
/// Returns (group sizes, the rank of each group) — e.g. `[3, 2]`, `[13, 4]` for K-K-K-4-4.
(List<int>, List<int>) _groups(List<int> ranks) {
  final counts = <int, int>{};
  for (final r in ranks) {
    counts[r] = (counts[r] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : b.compareTo(a);
    });
  return ([for (final k in keys) counts[k]!], keys);
}

int? _straightHigh(List<int> ranks) {
  final distinct = ranks.toSet();
  if (distinct.length != 5) return null;
  final sorted = distinct.toList()..sort();
  if (sorted.last - sorted.first == 4) return sorted.last;
  if (distinct.containsAll(const [14, 2, 3, 4, 5])) return 5;
  return null;
}

bool _shape(List<int> sizes, List<int> want) {
  if (sizes.length != want.length) return false;
  for (var i = 0; i < want.length; i++) {
    if (sizes[i] != want[i]) return false;
  }
  return true;
}

Hand5Rank _rank5(List<int> ranks, {required bool flush, required bool wild}) {
  final (sizes, keys) = _groups(ranks);
  final straight = _straightHigh(ranks);
  final desc = List.of(ranks)..sort((a, b) => b.compareTo(a));
  Hand5Rank r(Hand5Category c, List<int> tb) => Hand5Rank(c, tb, isWild: wild);

  if (straight != null && flush) {
    return r(Hand5Category.straightFlush, [straight]);
  }
  if (sizes.first == 4) return r(Hand5Category.fourOfAKind, keys);
  if (_shape(sizes, const [3, 2])) return r(Hand5Category.fullHouse, keys);
  if (flush) return r(Hand5Category.flush, desc);
  if (straight != null) return r(Hand5Category.straight, [straight]);
  if (sizes.first == 3) return r(Hand5Category.threeOfAKind, keys);
  if (_shape(sizes, const [2, 2, 1])) return r(Hand5Category.twoPair, keys);
  if (sizes.first == 2) return r(Hand5Category.onePair, keys);
  return r(Hand5Category.highCard, desc);
}

Hand3Rank _rank3(List<int> ranks, {required bool wild}) {
  final (sizes, keys) = _groups(ranks);
  Hand3Rank r(Hand3Category c, List<int> tb) => Hand3Rank(c, tb, isWild: wild);
  if (sizes.first == 3) return r(Hand3Category.threeOfAKind, keys);
  if (sizes.first == 2) return r(Hand3Category.pair, keys);
  return r(Hand3Category.highCard, keys);
}
