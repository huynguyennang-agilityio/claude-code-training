import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/profile/domain/entities/country.dart';
import 'package:stridequest/features/profile/domain/units/unit_conversion.dart';

void main() {
  group('height', () {
    test('180.3 cm is 5 ft 11 in, as in the design', () {
      expect(cmToFeetInches(180.3), (feet: 5, inches: 11));
    });

    test('rounds to the nearest inch and carries into the feet', () {
      expect(cmToFeetInches(182.8), (feet: 6, inches: 0)); // 71.97 in
      expect(cmToFeetInches(50), (feet: 1, inches: 8));
      expect(cmToFeetInches(272), (feet: 8, inches: 11));
    });

    test('feet and inches go back to centimetres with one decimal', () {
      expect(feetInchesToCm(5, 11), 180.3);
      expect(feetInchesToCm(6, 0), 182.9);
      expect(feetInchesToCm(0, 20), 50.8);
      expect(feetInchesToCm(5, 10.5), 179.1);
    });
  });

  group('weight', () {
    test('84.4 kg is 186.1 lb', () {
      expect(kgToLbs(84.4), 186.1);
    });

    test('pounds go back to kilograms with one decimal', () {
      expect(lbsToKg(186), 84.4);
      expect(lbsToKg(44.1), 20.0);
      expect(lbsToKg(881.8), 400.0);
    });
  });

  test('formatNumber drops a trailing .0', () {
    expect(formatNumber(180.0), '180');
    expect(formatNumber(180.3), '180.3');
    expect(formatNumber(84.44), '84.4');
  });

  test('roundToTenth rounds half away from zero', () {
    expect(roundToTenth(1.25), 1.3);
    expect(roundToTenth(1.24), 1.2);
  });

  group('Country', () {
    test('the list has the 249 ISO codes, each two capitals and unique', () {
      final codes = Country.all.map((c) => c.code).toList();

      expect(codes.length, 249);
      expect(codes.toSet().length, 249);
      expect(codes.every((c) => RegExp(r'^[A-Z]{2}$').hasMatch(c)), isTrue);
    });

    test('finds a country by code', () {
      expect(Country.byCode('VN')?.name, 'Vietnam');
      expect(Country.byCode('US')?.name, 'United States');
      expect(Country.byCode('ZZ'), isNull);
      expect(Country.byCode(null), isNull);
    });
  });
}
