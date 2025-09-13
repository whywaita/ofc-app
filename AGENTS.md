# Repository Guidelines

本書は本リポジトリの貢献ガイドです。最新の実装方針・構成・運用コマンドを簡潔にまとめます。

## プロジェクト構成（要点）
- ルート: `lib/`（ドメイン）`test/`（ユニット）`docs/`（要件/タスク）`.github/workflows/ci.yml`
- ドメイン（純Dart）: `core/models`（Rank/Suit/PlayingCard/Deck）、`features/game/domain`
  - 主要: `hand_evaluator.dart` `hand_category3/5.dart` `ruleset.dart` `foul_checker.dart`
          `score_engine.dart` `fantasy_engine.dart` `pineapple_engine.dart` `cycle_logic.dart`
          `board.dart` `board_builder.dart` `game_state.dart`
- アプリ（Flutter）: `app/`（Android/iOS のみ）
  - 主要: `lib/main.dart` `lib/game_screen.dart`（D&D配置/Next3-Commit統一/Sort）
          `lib/result_screen.dart`（役/ロイヤリティ/ActionLog）

## タスク実行（Makefile）
- 解析/テスト/ビルド: `make analyze` `make test` `make build` `make ci`
- 整形: `make format`
- 実行: `make app-run DEVICE="iPhone 15"`（シミュ/実機）／Xcode: `make app-ios-open`
- CI: PR/Pushで Dart/Flutter の analyze/test/build（pub キャッシュ最適化済）

## 実装ルール・コーディング
- Dart 標準（2スペース/Null-safety）。`package:lints` を適用。命名は `lower_snake_case`/`PascalCase`/`lowerCamelCase`。
- ドメインは副作用なしの純Dartに寄せる。UIは状態最小・ヘルパ分離を優先。
- ログに `print` を使わない（必要時は将来のロガー導入を想定）。

## テスト方針
- ルート: `dart test`（CycleLogic/役判定/採点など）。アプリ: `flutter test`（スモーク）。
- 追加のユニットは `*_test.dart` で小さく、決定的に。カバレッジ目安 60%+、ドメインは優先的に。

## コミット/PR
- Conventional Commits（例: `feat(game): unify next3 button`）。小さく分割し CI グリーンで提出。
- PR には目的/変更点/テスト結果、UI変更はスクショを添付。

## 署名/セキュリティ
- 機密情報はコミット禁止。iOS 実機は Xcode で Team を選択し自動署名（`make app-ios-open`）。
- 現状プラットフォームは Android/iOS のみ（web/macos/windows/linux は削除済）。
