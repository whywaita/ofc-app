enum WildMode { none, deuces, joker }

class GameOptions {
  final WildMode wildMode;
  const GameOptions({this.wildMode = WildMode.none});

  static const standard = GameOptions();
  static const deucesWild = GameOptions(wildMode: WildMode.deuces);
  static const jokerWild = GameOptions(wildMode: WildMode.joker);

  bool get isDeucesWild => wildMode == WildMode.deuces;
  bool get isJokerWild => wildMode == WildMode.joker;
  bool get hasWild => wildMode != WildMode.none;
}
