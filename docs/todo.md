# OFCP Flutter 実装タスク分解 v0.1（Codex向け）

> 前提: 要件定義 v0.2 に準拠。MVPはオフライン対戦のみ。Pineapple デフォルト、時間制無効、2人制、Fantasyは手動配置。対応端末は iOS/Android の最新メジャー2メジャーのみ。

---

## 更新履歴 / 進捗（2025-09-13 時点の追記）

- コア実装: カード/デッキ、役評価(5/3)、フォウル、ロイヤリティRuleset、スコア計算、Pineapple進行、Fantasy状態、2人用GameState 完了。単体テスト追加。
- 進行ロジック: Next3判定と自動Discardをサービス化（`CycleLogic`）。初手5=5枚配置、以降3枚サイクル=2枚配置でNext3可、残1枚は自動Discard。
- UI（Practice）: ドラッグ&ドロップ配置、同サイクル内の移動/Tray戻し、Discard枠撤去、縦レイアウト、絵文字スーツ（♥♦赤）。主ボタン（左下）を Next3/Commit で統一。Fantasy時のみ Sort（左配置、主ボタンと50%ずつ）。
- Result: 役/ロイヤリティに加え ActionLog（draw/place/discard/commit）を表示。
- テスト: ドメイン一式 + `cycle_logic_test` 追加。UIスモーク維持。
- CI: GitHub Actions 導入（Dart/Flutterの analyze/test/build）＋ pub キャッシュ最適化。
- 補助: Makefile（analyze/test/build/format/app-run/app-ios-open）。

## 0. リポジトリ/プロジェクト初期化

* [ ] Flutter 3.22+/Dart 3+ を `fvm` で固定。`fvm_config.json` 設置。
* [ ] パッケージ: `riverpod`, `flutter_hooks`, `freezed`, `json_serializable`, `build_runner`, `go_router`, `collection`, `equatable`, `uuid`, `hive`, `hive_flutter`, `logger`。
* [x] Lint: `very_good_analysis` or `flutter_lints`。`analysis_options.yaml` にルール設定、CIで警告をエラー化。（現状: `package:lints/recommended` を適用）
* [x] CI: GitHub Actions で `dart analyze/test` と `app` の `flutter analyze/test/build bundle`（pubキャッシュ最適化）を実行。
* [ ] pre-commit: `dart format --set-exit-if-changed` と `flutter analyze` をフック。
* [ ] 環境: `.env.example`（本MVPでは空に近い）。
* [ ] ディレクトリ構造:

  ```
  lib/
    app/
      router/
      theme/
    core/
      models/        # Card, Hand, Board, Score 等
      services/      # RNG, Storage, Logger
      utils/         # 比較/採点
    features/
      game/
        domain/      # 役判定/スコア/フォウル等
        application/ # StateNotifier(またはAsyncNotifier)
        presentation/# 画面/Widget
      bot/
        domain/
        application/
      tutorial/
      results/
    l10n/
  test/
  ```

---

## 1. ドメイン: カード/役/採点

### 1.1 カード・デッキ

* [x] `PlayingCard { rank(A..2), suit(♠♥♦♣) }`、`Deck` 実装。Fisher–Yates シャッフル (ローカルPRNG)。
* [ ] JSON シリアライズ（`freezed` + `json_serializable`）。

### 1.2 役判定（5枚役/3枚役）

* [x] 5枚: RF/SF/Four/Full/Flush/Straight/Three/TwoPair/Pair/High の判定、`Hand5Rank` 列挙と比較器。
* [x] 3枚: Trips/Pair/High の判定、`Hand3Rank` と比較器。
* [x] Kickers 含む厳密比較（同役内の優劣）。
* [ ] プロパティテスト: 乱択5万サンプルで順序反射・推移律を検証。

### 1.3 フォウル判定

* [x] `isFoul(board)` 実装（Bottom ≥ Middle ≥ Top）。リアルタイム利用のため O(1) 比較を意識。

### 1.4 ロイヤリティ

* [ ] JSONテーブル定義を読み込み、Top/Middle/Bottom で加点。要件定義 v0.2 の値をデフォルトに。
* [x] テーブル差し替え可能な `Ruleset` を実装。

### 1.5 スコアリング

* [x] 列ごとの勝敗: win=+1, lose=-1, tie=0。
* [x] スイープ: +3。
* [x] フォウル: 自分-6、相手+6、ロイヤリティ無効。
* [x] 合算関数 `Score compare(Board a, Board b, Ruleset r)`。

---

## 2. Pineapple/進行/履歴

### 2.1 Pineapple 配布

* [x] 初手5枚→以降 `3枚受取→2枚配置+1枚自動捨て`。Next3押下時に残1枚を自動Discard。
* [x] 捨て札は非公開。ResultのActionLogで参照可。

### 2.2 Fantasy

* [x] トリガー: Top QQ/KK/AA のペア、または Top Trips。配布枚数: QQ=14, KK=15, AA=16, Trips=17。
* [x] 継続条件: 次ハンドで `Top Trips` または `Bottom Four+` 達成で継続。セーフティ上限は内部に optional（既定: 無制限）。
* [x] 操作: Fantasy 中は全て手動配置。Sortボタンでトレイをソート（左下、主ボタンと並列）。

### 2.3 状態機械

* [x] `GameState { deck, turn, boardA, boardB, phase(drawing|placing|committed), history }`。
* [x] 時間制無し。ターン遷移は配置完了/コミットでのみ進行。
* [ ] Undo/Redo: （現状スコープ外）

### 2.4 履歴/監査（ローカル）

* [ ] `ActionLog`（受取/配置/捨て/コミット）をローカル保存。将来サーバ監査へ移行可能な形で設計。

---

## 3. Bot（ヒューリスティック）

* [ ] 目標: フォウル率 < 3%。
* [ ] ロジック: 上段はペア優先、中段/下段で強役形成を優先、終盤はフォウル回避を最優先。
* [ ] 難易度: Easy/Normal（選好スコアの閾値のみ変更）。
* [ ] パフォ: 1手の思考を \~200ms 以内に。
* [ ] 統計テスト: 1万局自己対戦でフォウル率/平均スコアを出力し閾値検証。

---

## 4. UI/UX

### 4.1 画面

* [ ] スプラッシュ/初回チュートリアル（1分チュートリアル）。
* [ ] ホーム（練習開始/設定/履歴）。
* [ ] 対戦画面（手札トレイ、Top/Mid/Bot スロット、未配置枚数、ヒントハイライト、リアルタイムフォウル警告）。
* [x] Result画面（役/ロイヤリティ、FOUL/OK、ActionLog、Fantasy告知）。
* [x] Practice画面（ドラッグ&ドロップ、同サイクル移動/Tray戻し、Discard枠撤去、縦レイアウト、絵文字スーツ、主ボタン統一、Sort配置）。

### 4.2 操作

* [ ] タップ移動とドラッグ両対応。ドロップ判定のスナップ閾値設定。
* [ ] 候補ハイライトと**自動ソート**ボタン（おすすめ配置順に並べ替えのみ）。
* [ ] 取り消し/やり直し（MVPは取り消し1段）。

### 4.3 ルック&フィール

* [ ] カードスキン1種。ライト/ダークはOS設定に追従。
* [ ] アクセシビリティ: ラベル、動作アニメ抑制オプション、色覚対応パレット。

---

## 5. 永続化/設定

* [ ] Hive 初期化。`UserPrefs { locale, theme, hintsEnabled }`。
* [ ] `SavedGame` の保存/再開（アプリ復帰時に同期）。
* [ ] 履歴10件保存（サイズ上限でローテーション）。

---

## 6. 計測/ログ

* [ ] `logger` でイベントログ。将来の Analytics 連携を想定し、`TelemetryEvent` を1箇所に定義。
* [ ] 主要イベント: `match_start`, `place_card`, `foul_warn`, `sweep`, `fantasy_enter`, `fantasy_continue`, `match_end`。

---

## 7. テスト戦略

* [x] ユニット: 役判定/比較/フォウル/ロイヤリティ/スコアリング。
* [ ] ゴールデン: 代表ケース30→段階的に100へ。期待値はJSONで保持。
* [ ] 乱択: 1e5 サンプルで役比較の順序性・回帰検出。
* [ ] Bot統計: シミュレーションでフォウル率<3%をアサート。
* [ ] UIテスト: フォウル時のリアルタイム警告、Fantasy配布枚数、スイープ/内訳表示。
* [x] （追加）CycleLogic のユニットテスト。
* [x] （追加）UIスモーク: サンプル対戦のスコア表示。

---

## 8. 受け入れ基準（抜粋）

* [ ] フォウル配置は確定不可で即時警告が表示される。
* [ ] Top QQ/KK/AA/Trips で Fantasy に突入し、配布枚数が要件どおりになる。
* [ ] 次ハンドで Top Trips または Bottom Four+ を満たすと Fantasy 継続。
* [ ] 列勝敗/スイープ/フォウル/ロイヤリティが計算表と一致する。
* [x] 捨て札は対局中非公開、Result画面のActionLogで参照可。
* [ ] アプリ再起動後にローカル保存の対局が復元される。

---

## 9. マイルストーン

* M1: ドメイン完成（1.1〜1.5、テスト含む）
* M2: 進行/履歴/状態機械（2.x 完了）
* M3: Bot 初版 + 統計テスト
* M4: UI結線（ボード/リザルト/チュートリアル）
* M5: 永続化/計測
* M6: QA/パフォーマンス/ベータビルド

---

## 10. ファイル/クラス雛形（例）

```text
lib/core/models/playing_card.dart
lib/core/models/hand5_rank.dart
lib/core/models/hand3_rank.dart
lib/features/game/domain/hand_evaluator.dart
lib/features/game/domain/foul_checker.dart
lib/features/game/domain/royalty_scorer.dart
lib/features/game/domain/score_engine.dart
lib/features/game/domain/pineapple_engine.dart
lib/features/game/domain/fantasy_engine.dart
lib/features/game/application/game_controller.dart  # StateNotifier
lib/features/game/presentation/game_screen.dart
lib/features/results/presentation/result_screen.dart
lib/features/bot/domain/bot_policy.dart
lib/features/bot/application/bot_controller.dart
lib/app/router/app_router.dart
lib/app/theme/app_theme.dart
```

---

## 11. 設定値（デフォルト）

```json
{
  "pineapple": true,
  "timers": {"enabled": false},
  "fantasy": {
    "qq": 14, "kk": 15, "aa": 16, "tripsTop": 17,
    "continue": {"topTrips": true, "bottomFourPlus": true},
    "maxChains": null
  },
  "royalties": {
    "top": {"pairs": {"66":1, "77":1, "88":1, "99":1, "TT":1, "JJ":2, "QQ":3, "KK":4, "AA":5}, "tripsBase": 7},
    "middle": {"three":2, "straight":4, "flush":8, "fullHouse":12, "four":20, "straightFlush":30},
    "bottom": {"straight":2, "flush":4, "fullHouse":6, "four":10, "straightFlush":15}
  },
  "sweepBonus": 3
}
```

---

## 12. 将来(参考、実装しない)

* オンライン: ルーム/マッチング/サーバシャッフル/切断復帰/監査。
* 認証: 匿名→連携（Apple/メール）。
* 観戦、トーナメント、ランキング。

```
```
