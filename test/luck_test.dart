import 'dart:math';

import 'package:chan/services/luck.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	test('distribution', () {
		final random = Random(0);
		for (int it = 0; it < 100; it++) {
			final total = random.nextInt(1 + pow(10, random.nextInt(4)).round());
			final bins = <int, int>{};
			for (int j = 0; j < total; j++) {
				final codeUnits = (random.nextInt(100000) + 1000).toString().codeUnits;
				final last = codeUnits.last;
				int i;
				for (i = 1; codeUnits[codeUnits.length - i] == last && i < codeUnits.length; i++) {
					// Go through each matching digits
				}
				i--; // we exit loop on i == too far by one
				bins.update(i, (x) => x + 1, ifAbsent: () => 1);
			}
			print(calculateLuck(data: (total, bins)));
		}
		print(calculateLuck(data: (528, {1: 488, 2: 38, 3: 1, 4: 1})));
		print(calculateLuck(data: (3845, {1: 3463, 2: 344, 3: 36, 4: 2})));
	});
}