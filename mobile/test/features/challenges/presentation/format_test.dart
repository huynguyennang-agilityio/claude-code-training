import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/presentation/format.dart';

void main() {
  test('formatNumber groups thousands', () {
    expect(formatNumber(0), '0');
    expect(formatNumber(999), '999');
    expect(formatNumber(1000), '1,000');
    expect(formatNumber(50000), '50,000');
    expect(formatNumber(1234567), '1,234,567');
  });

  test('formatKm drops a trailing .0', () {
    expect(formatKm(20000), '20');
    expect(formatKm(2500), '2.5');
    expect(formatKm(100000), '100');
  });

  test('a goal is steps for a run and kilometres otherwise', () {
    expect(formatGoal(ChallengeType.run, 50000), '50,000 steps');
    expect(formatGoal(ChallengeType.swim, 20000), '20 km');
    expect(formatGoal(ChallengeType.cycle, 100000), '100 km');
    expect(formatThreshold(ChallengeType.run, 20000), '20,000');
    expect(formatThreshold(ChallengeType.swim, 5000), '5 km');
  });

  test('formatCount shortens thousands', () {
    expect(formatCount(0), '0');
    expect(formatCount(813), '813');
    expect(formatCount(1000), '1K');
    expect(formatCount(1234), '1.2K');
    expect(formatCount(12500), '13K');
  });

  test('a range names the days, and the year when it is shown', () {
    final start = DateTime(2026, 10, 1);
    final end = DateTime(2026, 10, 31);

    expect(formatShortRange(start, end), 'Oct 1 – Oct 31');
    expect(formatFullRange(start, end), 'Oct 1 – Oct 31, 2026');
    expect(
      formatFullRange(DateTime(2026, 12, 20), DateTime(2027, 1, 10)),
      'Dec 20, 2026 – Jan 10, 2027',
    );
  });

  group('resizedImageUrl', () {
    const url =
        'https://res.cloudinary.com/demo/image/upload/v1/stridequest/a.jpg';

    test('inserts the transformations after upload', () {
      expect(
        resizedImageUrl(url, 800),
        'https://res.cloudinary.com/demo/image/upload/f_auto,q_auto,w_800/v1/stridequest/a.jpg',
      );
    });

    test('leaves an already transformed url and other hosts alone', () {
      const done =
          'https://res.cloudinary.com/demo/image/upload/f_auto,q_auto,w_100/a.jpg';

      expect(resizedImageUrl(done, 800), done);
      expect(
        resizedImageUrl('https://example.com/a.jpg', 800),
        'https://example.com/a.jpg',
      );
    });
  });
}
