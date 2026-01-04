import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board_builder.dart';
import 'helpers.dart';

void main() {
  group('BoardBuilder', () {
    late BoardBuilder builder;

    setUp(() {
      builder = BoardBuilder();
    });

    group('placeTop', () {
      test('adds cards to top row', () {
        builder.placeTop(c('As'));
        builder.placeTop(c('Ks'));
        expect(builder.top.length, 2);
        expect(builder.top, contains(c('As')));
        expect(builder.top, contains(c('Ks')));
      });

      test('throws when top is full (3 cards)', () {
        builder.placeTop(c('As'));
        builder.placeTop(c('Ks'));
        builder.placeTop(c('Qs'));
        expect(() => builder.placeTop(c('Js')), throwsStateError);
      });
    });

    group('placeMiddle', () {
      test('adds cards to middle row', () {
        builder.placeMiddle(c('As'));
        builder.placeMiddle(c('Ks'));
        expect(builder.middle.length, 2);
        expect(builder.middle, contains(c('As')));
        expect(builder.middle, contains(c('Ks')));
      });

      test('throws when middle is full (5 cards)', () {
        builder.placeMiddle(c('As'));
        builder.placeMiddle(c('Ks'));
        builder.placeMiddle(c('Qs'));
        builder.placeMiddle(c('Js'));
        builder.placeMiddle(c('Ts'));
        expect(() => builder.placeMiddle(c('9s')), throwsStateError);
      });
    });

    group('placeBottom', () {
      test('adds cards to bottom row', () {
        builder.placeBottom(c('As'));
        builder.placeBottom(c('Ks'));
        expect(builder.bottom.length, 2);
        expect(builder.bottom, contains(c('As')));
        expect(builder.bottom, contains(c('Ks')));
      });

      test('throws when bottom is full (5 cards)', () {
        builder.placeBottom(c('As'));
        builder.placeBottom(c('Ks'));
        builder.placeBottom(c('Qs'));
        builder.placeBottom(c('Js'));
        builder.placeBottom(c('Ts'));
        expect(() => builder.placeBottom(c('9s')), throwsStateError);
      });
    });

    group('remove', () {
      test('removes card from top row', () {
        builder.placeTop(c('As'));
        builder.placeTop(c('Ks'));
        expect(builder.remove(c('As')), isTrue);
        expect(builder.top.length, 1);
        expect(builder.top, isNot(contains(c('As'))));
      });

      test('removes card from middle row', () {
        builder.placeMiddle(c('As'));
        builder.placeMiddle(c('Ks'));
        expect(builder.remove(c('As')), isTrue);
        expect(builder.middle.length, 1);
        expect(builder.middle, isNot(contains(c('As'))));
      });

      test('removes card from bottom row', () {
        builder.placeBottom(c('As'));
        builder.placeBottom(c('Ks'));
        expect(builder.remove(c('As')), isTrue);
        expect(builder.bottom.length, 1);
        expect(builder.bottom, isNot(contains(c('As'))));
      });

      test('returns false when card not found', () {
        builder.placeTop(c('As'));
        expect(builder.remove(c('Ks')), isFalse);
        expect(builder.top.length, 1);
      });

      test('only removes from first matching row', () {
        builder.placeTop(c('As'));
        builder.placeMiddle(c('Ks'));
        builder.placeBottom(c('Qs'));
        expect(builder.remove(c('As')), isTrue);
        expect(builder.top, isEmpty);
        expect(builder.middle.length, 1);
        expect(builder.bottom.length, 1);
      });
    });

    group('isComplete', () {
      test('returns false when empty', () {
        expect(builder.isComplete, isFalse);
      });

      test('returns false when only top is full', () {
        builder.placeTop(c('As'));
        builder.placeTop(c('Ks'));
        builder.placeTop(c('Qs'));
        expect(builder.isComplete, isFalse);
      });

      test('returns false when only middle is full', () {
        builder.placeMiddle(c('As'));
        builder.placeMiddle(c('Ks'));
        builder.placeMiddle(c('Qs'));
        builder.placeMiddle(c('Js'));
        builder.placeMiddle(c('Ts'));
        expect(builder.isComplete, isFalse);
      });

      test('returns false when only bottom is full', () {
        builder.placeBottom(c('As'));
        builder.placeBottom(c('Ks'));
        builder.placeBottom(c('Qs'));
        builder.placeBottom(c('Js'));
        builder.placeBottom(c('Ts'));
        expect(builder.isComplete, isFalse);
      });

      test('returns true when all rows are full', () {
        // Top (3 cards)
        builder.placeTop(c('As'));
        builder.placeTop(c('Ks'));
        builder.placeTop(c('Qs'));
        // Middle (5 cards)
        builder.placeMiddle(c('Js'));
        builder.placeMiddle(c('Ts'));
        builder.placeMiddle(c('9s'));
        builder.placeMiddle(c('8s'));
        builder.placeMiddle(c('7s'));
        // Bottom (5 cards)
        builder.placeBottom(c('6s'));
        builder.placeBottom(c('5s'));
        builder.placeBottom(c('4s'));
        builder.placeBottom(c('3s'));
        builder.placeBottom(c('2s'));
        expect(builder.isComplete, isTrue);
      });
    });

    group('immutability', () {
      test('getters return unmodifiable views', () {
        builder.placeTop(c('As'));
        final topView = builder.top;
        // Attempting to modify should throw
        expect(() => topView.add(c('Ks')), throwsUnsupportedError);
      });

      test('cannot clear lists through getters', () {
        builder.placeMiddle(c('As'));
        final middleView = builder.middle;
        expect(() => middleView.clear(), throwsUnsupportedError);
        expect(builder.middle.length, 1);
      });

      test('cannot remove from lists through getters', () {
        builder.placeBottom(c('As'));
        final bottomView = builder.bottom;
        expect(() => bottomView.remove(c('As')), throwsUnsupportedError);
        expect(builder.bottom.length, 1);
      });
    });
  });
}
