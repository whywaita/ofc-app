import 'package:ofc_app_core/ofc_core.dart';

import 'hand_table_controller.dart';

/// Solo practice over a [PracticeSession].
class PracticeController extends HandTableController {
  PracticeController(
      {required int seed, GameOptions options = GameOptions.standard})
      : session = PracticeSession(seed: seed, options: options) {
    setStatus('Dealt ${hand.initialDrawCount}');
  }

  final PracticeSession session;

  @override
  PlayerHand get hand => session.hand;

  /// The seed that deals the current hand; entering it in Practice deals this hand again.
  int get handSeed => session.seed + session.handNumber - 1;

  /// Draws the next three. Only valid while the board is incomplete.
  void drawNext() {
    hand.drawNext();
    setStatus('Drew 3');
  }

  HandResult commit() {
    final r = session.commit();
    setStatus('Committed');
    return r;
  }

  void nextHand() {
    session.nextHand();
    setStatus('Dealt ${hand.initialDrawCount}');
  }
}
