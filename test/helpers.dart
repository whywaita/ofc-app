import 'package:ofc_app_core/ofc_core.dart';

/// Parses one card code such as `As`, `Td` or `JK`.
PlayingCard c(String code) => PlayingCard.parse(code);

/// Parses space-separated card codes: `cs('As Kd Qh')`.
List<PlayingCard> cs(String codes) =>
    codes.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map(c).toList();

/// Builds a board from three space-separated rows.
Board board(String top, String middle, String bottom) =>
    Board(top: cs(top), middle: cs(middle), bottom: cs(bottom));
