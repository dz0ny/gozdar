import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/compass_painter.dart';

void main() {
  const top = -pi / 2, right = 0.0, bottom = pi / 2, left = pi;

  double norm(double a) => (a % (2 * pi) + 2 * pi) % (2 * pi);
  Matcher at(double expected) =>
      predicate<double>((a) => (norm(a) - norm(expected)).abs() < 1e-9);

  test('facing north, north is at the top and east on the right', () {
    expect(CompassPainter.screenAngle(0, 0), at(top));
    expect(CompassPainter.screenAngle(90, 0), at(right));
  });

  test('facing east, north is on the left and east at the top', () {
    expect(CompassPainter.screenAngle(0, 90), at(left));
    expect(CompassPainter.screenAngle(90, 90), at(top));
    expect(CompassPainter.screenAngle(270, 90), at(bottom));
  });

  test('a target straight ahead is at the top for any heading', () {
    for (final heading in [0.0, 37.0, 180.0, 299.0]) {
      expect(CompassPainter.screenAngle(heading, heading), at(top));
    }
  });
}
