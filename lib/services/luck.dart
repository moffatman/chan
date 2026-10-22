import 'dart:math' as math;

import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';

int countTrailingMatchingDigits(int id) {
	if (id < 0) {
		throw ArgumentError.value(id, 'id', 'Must be nonnegative');
	}
	final digit = id % 10;
	int length = 1;
	for (int remaining = id ~/ 10; remaining > 0 && remaining % 10 == digit; remaining ~/= 10) {
		length++;
	}
	return length;
}

(int total, Map<int, int> bins) _calculate() {
	int total = 0;
	final bins = <int, int>{};
	for (final ts in Persistence.sharedThreadStateBox.values) {
		for (final receipt in ts.receipts) {
			if (receipt.spamFiltered) {
				continue;
			}
			total++;
			final i = countTrailingMatchingDigits(receipt.id);
			bins.update(i, (x) => x + 1, ifAbsent: () => 1);
		}
	}
	return (total, bins);
}

// Lanczos approximation for positive arguments (all callers use x >= 1).
double _logGamma(double x) {
	const coefficients = [
		676.5203681218851,
		-1259.1392167224028,
		771.3234287776531,
		-176.6150291621406,
		12.507343278686905,
		-0.13857109526572012,
		9.984369578019572e-6,
		1.5056327351493116e-7
	];
	final z = x - 1;
	double a = 0.99999999999980993;
	for (int i = 0; i < coefficients.length; i++) {
		a += coefficients[i] / (z + i + 1);
	}
	final t = z + 7.5;
	return 0.9189385332046727 + (z + 0.5) * math.log(t) - t + math.log(a);
}

double _negBinomialMidPercentile(int r, double p, int observed) {
	if (r == 0 || p == 1) {
		return observed == 0 ? 0.5 : 1.0;
	}
	final q = 1 - p;
	// Start at the observed PMF in log space: p^r alone can underflow even
	// when the final probability is near 50%.
	final logMass = _logGamma((r + observed).toDouble()) -
		_logGamma(r.toDouble()) - _logGamma((observed + 1).toDouble()) +
		r * math.log(p) + observed * math.log(q);
	final mass = math.exp(logMass);
	double term = mass;
	double tail = 0;
	if (observed < r * q / p) {
		// Sum the lower tail directly, avoiding 1 - CDF cancellation.
		for (int k = observed; k > 0; k--) {
			term *= k / (r + k - 1) / q;
			tail += term;
			if (term <= tail * 1e-15) break;
		}
		return (tail + 0.5 * mass).clamp(0.0, 1.0);
	}
	// Above the mean the upper tail converges faster.
	for (int k = observed; ; k++) {
		term *= (r + k) / (k + 1) * q;
		tail += term;
		if (term <= tail * 1e-15) break;
	}
	return (1 - tail - 0.5 * mass).clamp(0.0, 1.0);
}

double luckScore(int total, Map<int, int> bins, {double p = 0.9}) {
	// Returns a 0–1 midpoint percentile for total extra matching digits.
	// For independent uniform decimal digits, the stop probability is 0.9,
	// and the sum of (run length - 1) follows NegativeBinomial(total, p).
	if (total < 0) {
		throw ArgumentError.value(total, 'total', 'Must be nonnegative');
	}
	if (!p.isFinite || p <= 0 || p > 1) {
		throw ArgumentError.value(p, 'p', 'Must be in (0, 1]');
	}
	int count = 0;
	int observed = 0;
	for (final bin in bins.entries) {
		if (bin.key < 1 || bin.value < 0) {
			throw ArgumentError.value(bins, 'bins', 'Lengths must be positive and counts nonnegative');
		}
		count += bin.value;
		observed += (bin.key - 1) * bin.value;
	}
	if (count != total) {
		throw ArgumentError.value(bins, 'bins', 'Counts must sum to total');
	}
	// Half the probability of a tie centers the percentile at 50% under
	// the model, unlike a strict CDF, which is biased down for discrete data.
	return _negBinomialMidPercentile(total, p, observed);
}

double? calculateLuck({(int total, Map<int, int> bins)? data}) {
	final (total, bins) = data ?? _calculate();
	if (total == 0) {
		return null;
	}
	return luckScore(total, bins);
}

Future<void> showLuckPopup({required BuildContext context}) async {
	final sorted = _calculate().$2.entries.toList();
	sorted.sort((a, b) {
		return a.key.compareTo(b.key);
	});

	await showAdaptiveDialog(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Luck'),
			content: Padding(
				padding: const EdgeInsets.only(top: 8),
				child: Table(
					columnWidths: const {
						0: FlexColumnWidth(),
						1: IntrinsicColumnWidth()
					},
					children: [
						if (sorted.isEmpty) const TableRow(
							children: [
								TableCell(child: Text('Posts')),
								TableCell(child: Text('0'))
							]
						)
						else for (final bin in sorted) TableRow(
							children: [
								TableCell(
									child: Text(switch (bin.key) {
										1 => 'Singles',
										2 => 'Dubs',
										3 => 'Trips',
										4 => 'Quads',
										5 => 'Quints',
										6 => 'Sexts',
										7 => 'Septs',
										8 => 'Octs',
										9 => 'Nons',
										10 => 'Decs',
										int x => 'Insane ($x)'
									}, textAlign: TextAlign.left),
								),
								TableCell(
									child: Text(bin.value.toString(), textAlign: TextAlign.right)
								)
							]
						)
					]
				)
			),
			actions: [
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context),
					child: const Text('Close')
				)
			]
		)
	);
}
