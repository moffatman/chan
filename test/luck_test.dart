import 'dart:math' as math;

import 'package:chan/services/luck.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	test('counts trailing runs, including IDs whose digits all match', () {
		const cases = {
			0: 1, 7: 1, 12: 1, 11: 2, 111: 3, 111111: 6,
			123455: 2, 123555: 3, 1000: 3, 111110: 1,
			999999999: 9
		};
		for (final entry in cases.entries) {
			expect(countTrailingMatchingDigits(entry.key), entry.value,
				reason: 'ID ${entry.key}');
		}
		expect(() => countTrailingMatchingDigits(-1), throwsArgumentError);
	});

	test('all IDs below one million agree with an independent suffix regex', () {
		final suffix = RegExp(r'([0-9])\1*$');
		final bins = <int, int>{};
		for (int id = 0; id < 1000000; id++) {
			final expected = suffix.firstMatch(id.toString())!.group(0)!.length;
			final actual = countTrailingMatchingDigits(id);
			if (actual != expected) {
				fail('ID $id: expected $expected matching digits, got $actual');
			}
			bins.update(actual, (count) => count + 1, ifAbsent: () => 1);
		}
		expect(bins, {1: 900001, 2: 90000, 3: 9000, 4: 900, 5: 90, 6: 9});
	});

	test('long suffixes and 64-bit boundaries agree with the suffix regex', () {
		final suffix = RegExp(r'([0-9])\1*$');
		final ids = <int>{
			9007199254740991, 9007199254740992, 9007199254740993,
			9223372036854775807, 1111111111111111111,
			8888888888888888888, 1000000000000000000
		};
		for (int length = 1; length <= 19; length++) {
			for (int digit = 0; digit <= 9; digit++) {
				for (final prefix in ['', '1', '2', '10', '121']) {
					final id = int.tryParse('$prefix${digit.toString().padLeft(length, digit.toString())}');
					if (id != null) ids.add(id);
				}
			}
		}
		for (final id in ids) {
			expect(countTrailingMatchingDigits(id),
				suffix.firstMatch(id.toString())!.group(0)!.length, reason: 'ID $id');
		}
	});

	// Reference midpoint probabilities independently calculated by summing
	// NB PMFs with 90-digit decimal arithmetic, not a normal approximation.
	const screenshots = <(Map<int, int>, double)>[
		({1: 23042, 2: 2002, 3: 217, 4: 25, 5: 4}, 1.24520771640e-7),
		({1: 14011, 2: 1161, 3: 123, 4: 17, 5: 2}, 1.36263817130e-8),
		({1: 2310, 2: 38, 3: 5, 4: 2}, 1.32825709803e-51),
		({1: 690, 2: 72, 3: 7}, 0.530969561447),
		({1: 17152, 2: 1118, 3: 126, 4: 16, 5: 1}, 2.29900637223e-44),
		({1: 29697, 2: 2908, 3: 298, 4: 20, 5: 4}, 0.108649300290),
		({1: 8500, 2: 199, 3: 27, 4: 2}, 5.75194880423e-151),
		({1: 5949, 2: 585, 3: 52, 4: 1}, 0.0799121847423),
		({1: 997, 2: 44, 3: 1, 5: 1}, 2.13403281996e-11)
	];
	for (int i = 0; i < screenshots.length; i++) {
		test('screenshot ${i + 1} midpoint percentile, including tiny tails', () {
			final (bins, expected) = screenshots[i];
			final total = bins.values.fold(0, (int a, int b) => a + b);
			final actual = calculateLuck(data: (total, bins))!;
			expect(actual / expected, closeTo(1, 1e-8));
		});
	}

	test('single-post midpoint matches the geometric closed form', () {
		for (final p in [0.1, 0.5, 0.9, 0.99]) {
			for (int length = 1; length <= 12; length++) {
				final expected = 1 - (1 - p / 2) * math.pow(1 - p, length - 1);
				expect(luckScore(1, {length: 1}, p: p), closeTo(expected, 1e-12));
			}
		}
	});

	test('midpoint percentiles average 50 percent under the model', () {
		double average = 0;
		for (int length = 1; length <= 15; length++) {
			average += 0.9 * math.pow(0.1, length - 1) * luckScore(1, {length: 1});
		}
		expect(average, closeTo(0.5, 1e-12));
	});

	test('upper tail and large histories avoid intermediate underflow', () {
		expect(luckScore(1000, {1: 880, 2: 120}), closeTo(0.789875061887026, 1e-10));
		expect(luckScore(100000, {1: 90000, 2: 9000, 3: 1000}),
			closeTo(0.158656489977838, 1e-8));
		expect(luckScore(100000, {1: 100000}), 0);
		expect(luckScore(1, {1000: 1}), 1);
	});

	test('empty histories, deterministic distribution, and invalid inputs', () {
		expect(calculateLuck(data: (0, <int, int>{})), isNull);
		expect(luckScore(0, {}), 0.5);
		expect(luckScore(1, {1: 1}, p: 1), 0.5);
		expect(luckScore(1, {2: 1}, p: 1), 1);
		expect(() => luckScore(-1, {}), throwsArgumentError);
		expect(() => luckScore(1, {}), throwsArgumentError);
		expect(() => luckScore(1, {0: 1}), throwsArgumentError);
		expect(() => luckScore(1, {1: 2, 2: -1}), throwsArgumentError);
		for (final p in [0.0, -0.1, 1.1, double.nan, double.infinity]) {
			expect(() => luckScore(1, {1: 1}, p: p), throwsArgumentError);
		}
	});
}
