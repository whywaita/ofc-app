enum WildMode { none, deuces }

class GameOptions {
  final WildMode wildMode;
  const GameOptions({this.wildMode = WildMode.none});

  static const standard = GameOptions();
  static const deucesWild = GameOptions(wildMode: WildMode.deuces);

  bool get isDeucesWild => wildMode == WildMode.deuces;
}
