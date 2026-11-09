import 'package:backpack/common/weight_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double sum(List<double> w) => w.fold(0, (a, b) => a + b);

  test('parts are in proportion when all are big enough', () {
    final w = partWidths([1000, 3000], filled: 200, available: 300, minWidth: 6);
    expect(w[0], closeTo(50, 0.001));
    expect(w[1], closeTo(150, 0.001));
  });

  test('a tiny part still shows, taken from the big one; the total stays put', () {
    // 40 g of food next to 1.5 kg of gear, on a 100 px fill.
    final w = partWidths([40, 1500], filled: 100, available: 300, minWidth: 6);
    expect(w[0], closeTo(6, 0.001));
    expect(sum(w), closeTo(100, 0.001));
  });

  test('a barely filled bar still shows every part', () {
    // 40 g against 23 kg: well under a pixel of fill.
    final w = partWidths([40], filled: 0.5, available: 300, minWidth: 6);
    expect(w, [6]);
  });

  test('never wider than the bar', () {
    final w = partWidths([1, 1, 1], filled: 0, available: 10, minWidth: 6);
    expect(sum(w), closeTo(10, 0.001));
  });
}
