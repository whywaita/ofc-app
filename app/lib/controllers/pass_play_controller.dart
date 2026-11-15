import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';
import 'hand_table_controller.dart';

/// Two players on one device over a [HeadsUpMatch].
class PassPlayController extends HandTableController {
  PassPlayController({this.options = GameOptions.standard, int? seed})
      : _match = HeadsUpMatch(options: options, seed: seed) {
    setStatus('Dealt A/B');
  }

  final GameOptions options;
  HeadsUpMatch _match;

  HeadsUpMatch get match => _match;

  @override
  PlayerHand get hand => _match.currentHand;

  Player get current => _match.current;

  @override
  String get advanceLabel => hand.isComplete
      ? 'Commit (${current == Player.a ? 'A' : 'B'})'
      : 'Next 3';

  @override
  bool get canAdvance => _match.canAdvance;

  /// Commits or draws for the current player and passes the turn. Returns the result once both
  /// boards are committed.
  MatchResult? advance() {
    final committing = hand.isComplete;
    final before = current;
    _match.advance();
    final result = _match.result;
    if (result != null) {
      setStatus('Both committed');
    } else if (committing) {
      setStatus('${Labels.player(before)} committed');
    } else {
      setStatus('Drew 3');
    }
    return result;
  }

  /// Starts the next hand with each player's Fantasy state carried over.
  void nextHand() {
    _match = _match.nextMatch();
    setStatus('Dealt A/B');
  }
}
