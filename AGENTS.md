# Repository Guidelines

本書は本リポジトリの貢献ガイドです。最新の実装方針・構成・運用コマンドを簡潔にまとめます。

## プロジェクト構成（要点）
- ルート: `lib/`（ドメイン）`test/`（ユニット）`docs/`（要件/タスク）`.github/workflows/ci.yml`
- ドメイン（純Dart）: 公開 API は `package:ofc_app_core/ofc_core.dart` のみ。実装は `lib/src/`
  - `cards/`（Rank/Suit/PlayingCard[sealed: StandardCard/Joker]/Deck）
  - `hands/`（`hand_rank.dart` Hand5Rank/Hand3Rank、`hand_evaluator.dart` ワイルドは全探索）
  - `board/`（Board、BoardEvaluation: Foul 判定とワイルドの Foul 回避割り当て）
  - `rules/`（GameOptions/WildMode、Ruleset ロイヤリティ、FantasyState）
  - `scoring/`（ScoreEngine: ゼロサムのヘッズアップ採点）
  - `engine/`（PlayerHand: 配置ルールと ActionLog、PracticeSession、HeadsUpMatch）
- アプリ（Flutter）: `app/`
  - `lib/controllers/`（HandTableController と Practice/PassPlay の ChangeNotifier）
  - `lib/screens/`（home / practice / practice_result / pass_play / pass_play_result）
  - `lib/widgets/`（`hand_table.dart` 共通盤面: D&D・タップ・Semantics、card/result_board/seed_dialog）
  - `lib/presentation/labels.dart`（表示文言の一元化）

## タスク実行（Makefile）
- 解析/テスト/ビルド: `make analyze` `make test` `make build` `make ci`
- 整形: `make format`
- 実行: `make app-run DEVICE="iPhone 15"`（シミュ/実機）／Xcode: `make app-ios-open`
- Web ビルド: `make app-build-web`（静的ファイル → `app/build/web`）
- Web 検証: `make verify-web`（Flutter web をビルドして vlmkit の gate を実行。詳細と限界は `docs/vlmkit.md`）
- CI: PR/Pushで Dart/Flutter の analyze/test/build（pub キャッシュ最適化済）／vlmkit の Web 検証は `verify-web.yml`

## 実装ルール・コーディング
- Dart 標準（2スペース/Null-safety）。`package:lints` を適用。命名は `lower_snake_case`/`PascalCase`/`lowerCamelCase`。
- ドメインは副作用なしの純Dartに寄せる。UIは状態最小・ヘルパ分離を優先。
- ログに `print` を使わない（必要時は将来のロガー導入を想定）。

## テスト方針
- **テストは必須**: すべての実装において、テストコードを必ず作成すること。テストなしのコードは受け入れられない。
- **t_wada の TDD 手法を採用**:
  1. 🔴 **Red**: まず失敗するテストを書く（期待する振る舞いを定義）
  2. 🟢 **Green**: テストを通すための最小限の実装を行う
  3. 🔵 **Refactor**: 動作を保ったままコードを整理・改善する
  4. 小さなサイクルで繰り返し、常にテストがグリーンの状態を保つ
- **テストの実行環境**:
  - ルート: `dart test`（CycleLogic/役判定/採点など）
  - アプリ: `flutter test`（スモーク）
- **テストの品質**:
  - 追加のユニットは `*_test.dart` で小さく、決定的に
  - カバレッジ目安 60%+、ドメインロジックは優先的にカバー
  - エッジケース・エラーケース・正常系すべてをテスト

## コミット前チェックリスト
**⚠️ コミット前に必ず実行すること**:
1. `.github/workflows/ci.yml` を読んで、CI で実行されるすべてのチェックを把握する
2. ローカルで以下のコマンドを実行し、すべて成功することを確認:
   ```bash
   # ドメインロジック（ルート）
   dart pub get
   dart analyze lib test
   dart test -r expanded

   # Flutter アプリ
   cd app
   flutter pub get
   flutter analyze
   flutter test -r expanded
   flutter build bundle
   ```
3. または Makefile を使用:
   ```bash
   make ci  # すべてのチェックを一括実行
   ```
4. すべてのチェックがグリーンになってから `git commit` すること
5. CI が落ちた場合は、ログを確認して同じエラーをローカルで再現・修正してから再コミット

## コミット/PR
- Conventional Commits（例: `feat(game): unify next3 button`）。小さく分割し CI グリーンで提出。
- PR には目的/変更点/テスト結果、UI変更はスクショを添付。

## プラットフォーム優先順位

**Web が最優先プラットフォーム**。続いて Android/iOS の順。

機能実装やバグ修正時は:
1. まず Web で正しく動作することを確認
2. 次に Android/iOS で確認

※ macos/windows/linux は削除済

## 署名/セキュリティ
- 機密情報はコミット禁止。iOS 実機は Xcode で Team を選択し自動署名（`make app-ios-open`）。
