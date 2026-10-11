import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/providers/logs_provider.dart';

void main() {
  test('m³ converts to PRM and NM by dividing by the factor', () {
    const factors = ConversionFactors(prm: 0.65, nm: 0.40);

    // 1 PRM holds 0.65 m³ of solid wood, so 10 m³ fills ~15.4 PRM.
    expect(factors.toPrm(10), closeTo(15.38, 0.01));
    expect(factors.toNm(10), closeTo(25.0, 0.001));
    expect(factors.toPrm(0.65), closeTo(1, 1e-9));
  });

  test('a zero factor does not divide by zero', () {
    const factors = ConversionFactors(prm: 0, nm: 0);
    expect(factors.toPrm(10), 0);
    expect(factors.toNm(10), 0);
  });
}
