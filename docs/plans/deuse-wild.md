# Deuces Wild モード

## 概要

Deuces Wild は、標準52枚デッキの4枚の2（deuce）をワイルドカードとして扱うバリエーションルールです。ワイルドカードは任意のカードとして代用でき、プレイヤーにとって最も有利な役を自動的に形成します。

## 基本ルール

### ワイルドカード

- **52枚デッキ**（ジョーカーは追加しない）
- 4枚のデュース（2♠, 2♥, 2♦, 2♣）がワイルドカード
- ワイルドカードは任意のランク・スートのカードとして代用可能
- 自動的にプレイヤーにとって最も有利な役になるよう適用される

### 役の優先順位（5枚役・降順）

```
1. Royal Flush (Straight Flush A-high)
2. Straight Flush
3. Four of a Kind  ※Four Deucesもここに含む
4. Full House
5. Flush
6. Straight
7. Three of a Kind
8. Two Pair
9. One Pair
10. High Card
```

### 3枚役（Top段）

```
1. Three of a Kind（トリップス）
2. Pair（ペア）
3. High Card（ハイカード）
```

デュースを使って役を形成できます：
- 2枚のデュース + 任意1枚 = Three of a Kind（最高ランク）
- 1枚のデュース + ペア = Three of a Kind
- 1枚のデュース + 2枚の異なるカード = Pair（最高ランク）

## OFC特有のルール

### One Pair / Two Pair

ビデオポーカーの Deuces Wild では One Pair と Two Pair は役として成立しませんが、OFC（Open Face Chinese）では**役として認めます**。これはボード配置の制約上、必要な措置です。

### Fantasy Land

ワイルドカードを使用した役でも Fantasy Land の突入・継続条件を満たすことができます。

**突入条件**（Top段）：
- QQ（14枚配布）
- KK（15枚配布）
- AA（16枚配布）
- Trips（17枚配布）

**継続条件**：
- Top段 Trips
- Bottom段 Four of a Kind 以上

※ワイルド役でも条件を満たせば Fantasy Land に突入・継続できます。

### フォウル判定

フォウル判定はワイルドカード適用後の役強度で行います。Bottom ≥ Middle ≥ Top の順序が守られている必要があります。

## 使用例

### 4デュース + 5s
```
Hand: 2♠ 2♥ 2♦ 2♣ 5♠
Result: Straight Flush (9-high)
        5-6-7-8-9 of spades
```

### 3デュース + As + Ks（同スート）
```
Hand: 2♠ 2♥ 2♦ A♠ K♠
Result: Straight Flush (Royal)
        A-K-Q-J-T of spades
```

### 2デュース + ペア
```
Hand: 2♠ 2♥ A♠ A♦ K♠
Result: Four of a Kind (Aces)
```

### 1デュース + トリップス
```
Hand: 2♠ A♠ A♦ A♣ K♠
Result: Four of a Kind (Aces)
```

## API 使用方法

### GameOptions

```dart
// Deuces Wild モードでゲームを開始
final state = GameState(options: GameOptions.deucesWild);

// または
final state = GameState(
  options: GameOptions(wildMode: WildMode.deuces),
);
```

### BoardEval

```dart
// Deuces Wild モードでボードを評価
final eval = BoardEval.from(board, wildMode: WildMode.deuces);

// 役がワイルドカードを使用しているかチェック
if (eval.top.isWild) {
  print('Top row uses wild cards');
}
```

### ScoreEngine

```dart
// Deuces Wild モードでスコアを計算
final score = ScoreEngine.compare(
  boardA,
  boardB,
  wildMode: WildMode.deuces,
);
```

## 参考リンク

- [Deuces Wild - Wizard of Odds](https://wizardofodds.com/games/deuces-wild/)
- [Deuces Wild Video Poker Strategy | PokerNews](https://www.pokernews.com/casino/video-poker/deuces-wild.htm)
- [California Deuces Wild Pineapple Rules (PDF)](https://oag.ca.gov/sites/all/files/agweb/pdfs/gambling/deuces_wild.pdf)
