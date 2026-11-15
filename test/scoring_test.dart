import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const rules = Ruleset.standard;
const ev = HandEvaluator(WildMode.none);

BoardEvaluation eval(Board b, [WildMode mode = WildMode.none]) =>
    BoardEvaluation.of(b, wildMode: mode);

void main() {
  group('royalties', () {
    test('top pairs 66..AA pay 1..9', () {
      expect(rules.royaltyTop(ev.best3(cs('5c 5d 2h'))), 0);
      expect(rules.royaltyTop(ev.best3(cs('6c 6d 2h'))), 1);
      expect(rules.royaltyTop(ev.best3(cs('Jc Jd 2h'))), 6);
      expect(rules.royaltyTop(ev.best3(cs('As Ad 7c'))), 9);
    });

    test('top trips 222..AAA pay 10..22', () {
      expect(rules.royaltyTop(ev.best3(cs('2s 2d 2c'))), 10);
      expect(rules.royaltyTop(ev.best3(cs('Ks Kd Kc'))), 21);
      expect(rules.royaltyTop(ev.best3(cs('As Ah Ad'))), 22);
    });

    test('middle', () {
      expect(rules.royaltyMiddle(ev.best5(cs('7c 7d 7h Ks 2s'))), 2);
      expect(rules.royaltyMiddle(ev.best5(cs('6c 5d 4h 3s 2s'))), 4);
      expect(rules.royaltyMiddle(ev.best5(cs('2h 6h 9h Jh Qh'))), 8);
      expect(rules.royaltyMiddle(ev.best5(cs('Ks Kd Kc 4h 4s'))), 12);
      expect(rules.royaltyMiddle(ev.best5(cs('9s 9d 9c 9h 2s'))), 20);
      expect(rules.royaltyMiddle(ev.best5(cs('6d 7d 8d 9d Td'))), 30);
      expect(rules.royaltyMiddle(ev.best5(cs('Ad Kd Qd Jd Td'))), 50);
    });

    test('bottom', () {
      expect(rules.royaltyBottom(ev.best5(cs('7c 7d 7h Ks 2s'))), 0);
      expect(rules.royaltyBottom(ev.best5(cs('6c 5d 4h 3s 2s'))), 2);
      expect(rules.royaltyBottom(ev.best5(cs('2h 6h 9h Jh Qh'))), 4);
      expect(rules.royaltyBottom(ev.best5(cs('Ks Kd Kc 4h 4s'))), 6);
      expect(rules.royaltyBottom(ev.best5(cs('9s 9d 9c 9h 2s'))), 10);
      expect(rules.royaltyBottom(ev.best5(cs('6d 7d 8d 9d Td'))), 15);
      expect(rules.royaltyBottom(ev.best5(cs('Ad Kd Qd Jd Td'))), 25);
    });

    test('per board, and nothing on a foul', () {
      final ok = rules.royalties(
          eval(board('Qh Qs 2c', '7c 7d 7h Ks 3s', 'Ah Kh 9h 6h 4h')));
      expect([ok.top, ok.middle, ok.bottom, ok.total], [7, 2, 4, 13]);
      final foul = rules.royalties(
          eval(board('As Ad 2c', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc')));
      expect(foul.total, 0);
    });
  });

  group('ScoreEngine (zero-sum: what one player wins the other pays)', () {
    VersusScore score(String a, String b) {
      final ta = a.split('|'), tb = b.split('|');
      return ScoreEngine(rules).compare(
        eval(board(ta[0], ta[1], ta[2])),
        eval(board(tb[0], tb[1], tb[2])),
      );
    }

    const strong = '9s 9d 2c|Qs Qd 3h 5c 8d|Ks Kd Th Tc 3d';
    const swept = '8s 8h 3c|Js Jd 4h 6c 9d|Jc Jh 9c 9h 4c';
    const mixed = 'Ts Th 3c|Js Jd 4h 6c 9d|Ac Ah Ad 9h 4c';
    const fouled = 'As Ad 2c|3c 8d 8s Jc Ah|Td 9s 9h 6c Tc';
    const clean = 'Qh Qs 2c|Kd Kc 3d 7s 9h|Ah Ad 7c 6c 4d';

    test('a sweep wins three rows plus three, and royalties are netted', () {
      final res = score(strong, swept);
      // Rows +3, sweep +3, royalties 99 (+4) against 88 (+3) = +1.
      expect(res.a.rows.sum, 3);
      expect(res.a.sweep, 3);
      expect(res.a.royalties, 1);
      expect(res.a.total, 7);
      expect(res.b.sweep, -3, reason: 'the swept player pays the bonus');
      expect(res.b.total, -7);
    });

    test('mixed rows: no sweep, row points and net royalties', () {
      final res = score(strong, mixed);
      expect(
          [res.a.rows.top, res.a.rows.middle, res.a.rows.bottom], [-1, 1, -1]);
      expect(res.a.sweep, 0);
      // Royalties 99 (+4) against TT (+5) = -1.
      expect(res.a.total, -1 - 1);
      expect(res.b.total, 1 + 1);
    });

    test("one foul: the fouler pays six plus the opponent's royalties", () {
      final res = score(fouled, clean);
      expect(res.b.foul, 6);
      expect(res.b.royalties, 7,
          reason: 'QQ on top earns +7 even against a foul');
      expect(res.b.total, 13);
      expect(res.a.total, -13);
    });

    test('both foul: nobody scores', () {
      final res = score(fouled, fouled);
      expect(res.a.total, 0);
      expect(res.b.total, 0);
    });

    test('every pairing is zero-sum and mirrored', () {
      const boards = [strong, swept, mixed, fouled, clean];
      for (final a in boards) {
        for (final b in boards) {
          final res = score(a, b);
          expect(res.a.total + res.b.total, 0, reason: '$a vs $b');
          expect(res.b.rows.sum, -res.a.rows.sum);
          expect(res.b.sweep, -res.a.sweep);
          expect(res.b.royalties, -res.a.royalties);
          expect(res.b.foul, -res.a.foul);
        }
      }
    });
  });

  group('Fantasyland', () {
    final noEntry = board('Ah Kd 2c', '3d 4s 5c 7d 9h', 'Ad Kc 4d 6s 9c');

    test('entry counts: QQ 14, KK 15, AA 16, trips 17', () {
      FantasyState next(String top, String mid) => FantasyState.next(
          const FantasyState.inactive(),
          eval(board(top, mid, 'Ah Kh 9h 6h 4h')));
      expect(next('Jh Js 2c', 'Ac Ad 3d 7s 9s').initialCount, 0);
      expect(next('Qh Qs 2c', 'Ac Ad 3d 7s 9s').initialCount, 14);
      expect(next('Kh Ks 2c', 'Ac Ad 3d 7s 9s').initialCount, 15);
      expect(next('As Ad 2c', 'Kc Kd Ks 7s 9s').initialCount, 16);
      expect(next('5s 5d 5c', 'Kc Kd Ks 7s 9s').initialCount, 17);
    });

    test('no entry on a foul, even with aces on top', () {
      final st = FantasyState.next(const FantasyState.inactive(),
          eval(board('As Ad 2c', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc')));
      expect(st.isActive, isFalse);
    });

    test('continues on bottom quads, keeping the original deal', () {
      final st = FantasyState.next(const FantasyState.active(15),
          eval(board('2h 3h 4h', '2d 6d 8d 9d Td', '9s 9h 9c 9d 2s')));
      expect(st, const FantasyState.active(15));
    });

    test('continues on top trips', () {
      final st = FantasyState.next(const FantasyState.active(14),
          eval(board('5h 5d 5s', '2h 6h 8h 9h Th', '9s 9d 9c 4d 4s')));
      expect(st, const FantasyState.active(14));
    });

    test('ends otherwise', () {
      expect(
          FantasyState.next(const FantasyState.active(16), eval(noEntry))
              .isActive,
          isFalse);
    });

    test('deuces: wild trips on top enter with 17', () {
      final st = FantasyState.next(
          const FantasyState.inactive(),
          eval(board('2s 2h 9d', 'Kc Kd Ks 7s 3h', 'Ah Kh 9h 6h 4h'),
              WildMode.deuces));
      expect(st, const FantasyState.active(17));
    });

    test('deuces: wild quads on the bottom stay in', () {
      final st = FantasyState.next(
          const FantasyState.active(14),
          eval(board('3h 4h 6d', 'Kc Kd 5s 7s 9h', 'As Ad Ac 2c 8d'),
              WildMode.deuces));
      expect(st, const FantasyState.active(14));
    });

    test('wild hands count', () {
      final st = FantasyState.next(
          const FantasyState.inactive(),
          eval(board('JK Ks 6d', 'Ah Ad Ac 9h 8d', '9c 9s 9d 2c 2s'),
              WildMode.joker));
      expect(st, const FantasyState.active(15));
    });
  });
}
