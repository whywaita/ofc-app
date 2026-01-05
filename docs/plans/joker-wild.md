# Joker Wild オプション実装計画

## 概要

全てのゲームモード（Practice / Pass & Play）に「Joker Wild」オプションを追加する。このモードでは、標準52枚デッキに2枚のジョーカーを追加した54枚デッキを使用し、ジョーカーはワイルドカードとして機能する。

## Joker Wildのルール

### 基本ルール

参考: [Video Poker Baller - Jokers Wild](https://www.videopokerballer.com/games/jokers-wild/) / [Caesars Games - What is Joker Poker](https://www.caesarsgames.com/blog/what-is-joker-poker-and-how-to-play/)

1. **ジョーカーの挙動**
   - ジョーカーは任意のカードとして代用可能（ワイルドカード）
   - 自動的にプレイヤーにとって最も有利な役になるよう適用される
   - 同じランクの4枚 + ジョーカー = Five of a Kind が成立

2. **役の優先順位（5枚役・降順）**
   ```
   1. Natural Royal Flush   - ジョーカーなしのロイヤルフラッシュ（A,K,Q,J,10同スート）
   2. Five of a Kind        - 同ランク4枚 + ジョーカー（Joker Wild限定）
   3. Wild Royal Flush      - ジョーカーを含むロイヤルフラッシュ
   4. Straight Flush        - 同スートの連続5枚（ロイヤル以外）
   5. Four of a Kind        - 同ランク4枚
   6. Full House            - 3枚 + 2枚
   7. Flush                 - 同スート5枚
   8. Straight              - 連続5枚
   9. Three of a Kind       - 同ランク3枚
   10. Two Pair             - 2枚 × 2組
   11. One Pair             - 同ランク2枚
   12. High Card            - 上記いずれにも該当しない
   ```

3. **3枚役（Top段）の扱い**
   - Three of a Kind: 同ランク2枚 + ジョーカー で成立可能
   - Pair: 任意カード + ジョーカー で成立可能
   - ジョーカーは最も有利なランクとして適用

4. **OFC特有の考慮事項**
   - **Natural vs Wild の区別**: 同じカテゴリでもNatural（ジョーカーなし）が Wild（ジョーカーあり）より強い
   - **Fantasy Land**: 突入・継続条件はジョーカーを含む役でも有効とする
   - **フォウル判定**: ジョーカー適用後の役強度で判定

---

## 実装計画

### Phase 1: データモデルの拡張

#### 1.1 PlayingCard にジョーカー対応を追加

**ファイル**: `lib/core/models/playing_card.dart`

```dart
class PlayingCard {
  final Rank? rank;  // null for Joker
  final Suit? suit;  // null for Joker
  final bool isJoker;

  const PlayingCard(this.rank, this.suit) : isJoker = false;
  const PlayingCard.joker() : rank = null, suit = null, isJoker = true;

  // 既存メソッドの互換性維持
  factory PlayingCard.parse(String code) {
    if (code == 'JK' || code == 'Jk') {
      return PlayingCard.joker();
    }
    // 既存のパースロジック...
  }
}
```

**変更点**:
- `rank` と `suit` を nullable に変更
- `isJoker` フラグを追加
- `PlayingCard.joker()` コンストラクタを追加
- `parse()` で "JK" をジョーカーとして認識

#### 1.2 Deck にジョーカーデッキ対応を追加

**ファイル**: `lib/core/models/deck.dart`

```dart
class Deck {
  // 既存のファクトリ
  factory Deck.standard({int? seed}) { /* 52枚 */ }

  // 新規ファクトリ
  factory Deck.withJokers({int? seed, int jokerCount = 2}) {
    final cards = <PlayingCard>[];
    for (final s in Suit.values) {
      for (final r in Rank.values) {
        cards.add(PlayingCard(r, s));
      }
    }
    // ジョーカーを追加
    for (int i = 0; i < jokerCount; i++) {
      cards.add(PlayingCard.joker());
    }
    final deck = Deck._(cards);
    deck.shuffle(seed: seed);
    return deck;
  }
}
```

---

### Phase 2: 役判定エンジンの拡張

#### 2.1 Hand5Category の拡張

**ファイル**: `lib/features/game/domain/hand_category5.dart`

```dart
enum Hand5Category {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,       // 既存
  fiveOfAKind,         // 新規: Joker Wild限定
  wildRoyalFlush,      // 新規: ジョーカー含むロイヤル
  naturalRoyalFlush,   // 新規: ジョーカーなしロイヤル
}
```

**注意**: enumのindex順序が役の強さを表すため、追加順序に注意

#### 2.2 Hand5Rank の拡張

```dart
class Hand5Rank implements Comparable<Hand5Rank> {
  final Hand5Category category;
  final List<int> tiebreakers;
  final bool isWild;  // 新規: ジョーカーを使用しているか

  const Hand5Rank(this.category, this.tiebreakers, {this.isWild = false});

  @override
  int compareTo(Hand5Rank other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c;
    // 同カテゴリ内では Natural > Wild
    if (isWild != other.isWild) {
      return isWild ? -1 : 1;  // Naturalが勝ち
    }
    // 既存のtiebreaker比較...
  }
}
```

#### 2.3 HandEvaluator のワイルドカード対応

**ファイル**: `lib/features/game/domain/hand_evaluator.dart`

```dart
class HandEvaluator {
  /// 通常の5枚役判定（既存）
  static Hand5Rank evaluate5(List<PlayingCard> cards) { /* 既存 */ }

  /// ワイルドカード対応の5枚役判定（新規）
  static Hand5Rank evaluate5Wild(List<PlayingCard> cards) {
    final jokers = cards.where((c) => c.isJoker).length;
    final nonJokers = cards.where((c) => !c.isJoker).toList();

    if (jokers == 0) {
      // ジョーカーなし = 通常判定 + Royal判定
      return _evaluate5Natural(cards);
    }

    // ジョーカーあり = 全組み合わせから最強を探索
    return _findBestWithWilds(nonJokers, jokers);
  }

  /// 最強の役を探索（ブルートフォース or 最適化アルゴリズム）
  static Hand5Rank _findBestWithWilds(List<PlayingCard> fixed, int wildcards) {
    // 実装アプローチ:
    // 1. 役ごとに「この役が成立するか」をチェック
    // 2. 最強の役から順にチェックし、成立したら即リターン
    //
    // 例: Five of a Kind をチェック
    //   - fixed が同ランク4枚 and wildcards >= 1 → 成立
    //   - fixed が同ランク3枚 and wildcards >= 2 → 成立
  }
}
```

**実装方針（2つのアプローチ）**:

| アプローチ | 説明 | メリット | デメリット |
|-----------|------|----------|------------|
| **ブルートフォース** | ジョーカーを全52枚に置換して最強を探索 | 実装が単純、正確 | 計算量が大きい（最大52^2 = 2704パターン） |
| **役ベース判定** | 各役の成立条件をジョーカー数を考慮して判定 | 高速 | 実装が複雑、バグリスク |

**推奨**: 役ベース判定を採用（OFCではリアルタイム性が重要なため）

---

### Phase 3: ゲームロジックの拡張

#### 3.1 GameOptions の新設

**ファイル**: `lib/features/game/domain/game_options.dart`（新規）

```dart
class GameOptions {
  final bool jokerWild;  // ジョーカーワイルドモード
  final int jokerCount;  // ジョーカー枚数（デフォルト2）

  const GameOptions({
    this.jokerWild = false,
    this.jokerCount = 2,
  });

  static const standard = GameOptions();
  static const withJokers = GameOptions(jokerWild: true, jokerCount: 2);
}
```

#### 3.2 GameState の拡張

**ファイル**: `lib/features/game/domain/game_state.dart`

```dart
class GameState {
  final GameOptions options;  // 新規
  final Deck deck;
  // ...

  GameState({GameOptions? options, int? seed})
      : options = options ?? GameOptions.standard {
    // デッキ生成時にオプションを反映
    deck = options?.jokerWild == true
        ? Deck.withJokers(seed: seed, jokerCount: options!.jokerCount)
        : Deck.standard(seed: seed);
  }
}
```

#### 3.3 BoardEval の拡張

**ファイル**: `lib/features/game/domain/board.dart`

```dart
class BoardEval {
  static BoardEval evaluate(Board board, {bool wildMode = false}) {
    if (wildMode) {
      return BoardEval(
        top: HandEvaluator.evaluate3Wild(board.top),
        middle: HandEvaluator.evaluate5Wild(board.middle),
        bottom: HandEvaluator.evaluate5Wild(board.bottom),
      );
    }
    return BoardEval(
      top: HandEvaluator.evaluate3(board.top),
      middle: HandEvaluator.evaluate5(board.middle),
      bottom: HandEvaluator.evaluate5(board.bottom),
    );
  }
}
```

---

### Phase 4: ロイヤリティテーブルの拡張

#### 4.1 Ruleset の拡張

**ファイル**: `lib/features/game/domain/ruleset.dart`

```dart
class Ruleset {
  // 既存のロイヤリティ...

  // Joker Wild用の追加ロイヤリティ
  int royaltyBottomWild(Hand5Rank r) {
    switch (r.category) {
      case Hand5Category.naturalRoyalFlush:
        return 25;  // Natural Royal は最高ボーナス
      case Hand5Category.fiveOfAKind:
        return 20;  // Five of a Kind
      case Hand5Category.wildRoyalFlush:
        return 18;  // Wild Royal
      case Hand5Category.straightFlush:
        return r.isWild ? 12 : 15;  // Wild は減額
      // ... 他の役
    }
  }
}
```

**ロイヤリティ案（Bottom段・Joker Wild）**:

| 役 | Natural | Wild |
|----|---------|------|
| Natural Royal Flush | 25 | - |
| Five of a Kind | - | 20 |
| Wild Royal Flush | - | 18 |
| Straight Flush | 15 | 12 |
| Four of a Kind | 10 | 8 |
| Full House | 6 | 6 |
| Flush | 4 | 4 |
| Straight | 2 | 2 |

---

### Phase 5: UI の拡張

#### 5.1 ホーム画面にオプション追加

**ファイル**: `app/lib/main.dart`

- ゲーム開始前に「Joker Wild」トグルスイッチを追加
- オプション選択状態を GameOptions として渡す

#### 5.2 カードウィジェットのジョーカー対応

**ファイル**: `app/lib/widgets/card_widget.dart`

```dart
Widget build(BuildContext context) {
  if (card.isJoker) {
    return _buildJokerCard();  // ジョーカー専用デザイン
  }
  return _buildNormalCard();
}
```

#### 5.3 結果画面の表示拡張

**ファイル**: `app/lib/result_screen.dart`

- 「Wild」マークの表示（ジョーカーを使用した役の場合）
- Five of a Kind, Natural/Wild Royal の表示対応

---

### Phase 6: テストの追加

#### 6.1 単体テスト

**ファイル**: `test/hand_evaluator_wild_test.dart`（新規）

```dart
void main() {
  group('evaluate5Wild', () {
    test('Five of a Kind: 4 Aces + Joker', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spade),
        PlayingCard(Rank.ace, Suit.heart),
        PlayingCard(Rank.ace, Suit.diamond),
        PlayingCard(Rank.ace, Suit.club),
        PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.fiveOfAKind);
    });

    test('Wild Royal Flush', () { /* ... */ });
    test('Natural Royal Flush beats Wild Royal', () { /* ... */ });
    test('Joker makes best possible hand', () { /* ... */ });
  });
}
```

#### 6.2 統合テスト

**ファイル**: `test/game_state_joker_test.dart`（新規）

- Joker Wild モードでのゲーム進行テスト
- Fantasy Land 突入条件テスト（ジョーカー含む役）
- フォウル判定テスト（ジョーカー含む役）

---

## 実装順序

```
Phase 1: データモデル
├── 1.1 PlayingCard.joker 対応
└── 1.2 Deck.withJokers 対応
    ↓
Phase 2: 役判定
├── 2.1 Hand5Category 拡張
├── 2.2 Hand5Rank 拡張
└── 2.3 HandEvaluator.evaluate5Wild
    ↓
Phase 3: ゲームロジック
├── 3.1 GameOptions 新設
├── 3.2 GameState 拡張
└── 3.3 BoardEval 拡張
    ↓
Phase 4: ロイヤリティ
└── 4.1 Ruleset 拡張
    ↓
Phase 5: UI
├── 5.1 ホーム画面オプション
├── 5.2 カードウィジェット
└── 5.3 結果画面
    ↓
Phase 6: テスト
├── 6.1 単体テスト
└── 6.2 統合テスト
```

---

## 影響範囲

| ファイル | 変更内容 |
|----------|----------|
| `lib/core/models/playing_card.dart` | ジョーカー対応追加 |
| `lib/core/models/deck.dart` | `Deck.withJokers` 追加 |
| `lib/features/game/domain/hand_category5.dart` | 新役追加 |
| `lib/features/game/domain/hand_evaluator.dart` | ワイルド判定追加 |
| `lib/features/game/domain/game_state.dart` | GameOptions 対応 |
| `lib/features/game/domain/board.dart` | wildMode 対応 |
| `lib/features/game/domain/ruleset.dart` | ロイヤリティ拡張 |
| `lib/features/game/domain/foul_checker.dart` | wildMode 対応 |
| `lib/features/game/domain/score_engine.dart` | wildMode 対応 |
| `lib/features/game/domain/fantasy_engine.dart` | wildMode 対応 |
| `app/lib/main.dart` | オプションUI追加 |
| `app/lib/widgets/card_widget.dart` | ジョーカー描画 |
| `app/lib/result_screen.dart` | 新役表示対応 |

---

## リスクと対策

| リスク | 対策 |
|--------|------|
| ワイルドカード判定のバグ | 網羅的なテストケース + プロパティベーステスト |
| 計算量の増大 | 役ベース判定アルゴリズムの採用 |
| Natural vs Wild の比較漏れ | `isWild` フラグによる明示的な区別 |
| 既存コードへの影響 | デフォルトで `jokerWild = false` とし後方互換性を維持 |

---

## 参考リンク

- [Video Poker Baller - Jokers Wild](https://www.videopokerballer.com/games/jokers-wild/)
- [Caesars Games - What is Joker Poker](https://www.caesarsgames.com/blog/what-is-joker-poker-and-how-to-play/)
- [Wikipedia - Wild card (cards)](https://en.wikipedia.org/wiki/Wild_card_(cards))
- [Casino Encyclopedia - Jokers Wild Strategy](https://www.casinoencyclopedia.com/jokers-wild-strategy/)
