import 'dart:math' as math;

import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';

(int total, Map<int, int> bins) _calculate() {
	int total = 0;
	final bins = <int, int>{};
	for (final ts in Persistence.sharedThreadStateBox.values) {
		for (final receipt in ts.receipts) {
			if (receipt.spamFiltered) {
				continue;
			}
			total++;
			final codeUnits = receipt.id.toString().codeUnits;
			int i;
			if (codeUnits.length == 1) {
				i = 1;
			}
			else {
				final last = codeUnits.last;
				for (i = 1; codeUnits[codeUnits.length - i] == last && i < codeUnits.length; i++) {
					// Go through each matching digits
				}
				i--; // we exit loop on i == too far by one
			}
			bins.update(i, (x) => x + 1, ifAbsent: () => 1);
		}
	}
	return (total, bins);
}

double _erf(double x) {
  // Abramowitz-Stegun approximation
  final sign = x < 0 ? -1.0 : 1.0;
  x = x.abs();

  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const p = 0.3275911;

  final t = 1.0 / (1.0 + p * x);
  final y = 1.0 - (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t) *
      math.exp(-x * x);

  return sign * y;
}

double _normalCdf(double x) {
  return 0.5 * (1.0 + _erf(x / math.sqrt2));
}

double _negBinomialCdfApprox(int r, double p, int tMax) {
  if (tMax < 0) return 0.0;
  if (p <= 0.0) return 0.0;
  if (p >= 1.0) return 1.0;

  final q = 1.0 - p;
  final mean = r * q / p;
  final variance = r * q / (p * p);
  final sd = math.sqrt(variance);

  final z = (tMax + 0.5 - mean) / sd;
  return _normalCdf(z).clamp(0.0, 1.0);
}

double luckScore(int total, Map<int, int> bins, {double p = 0.9}) {
  // Returns a 0–100 luck score for a set of integers.
  // p is the geometric "success" prob (stop prob) for the trailing run extension.
  // For uniform base-10 last digits, p = 0.9.

  // Sum T_obs = Σ (k_i - 1)
  int tObs = 0;
  for (final bin in bins.entries) {
    tObs += (bin.key - 1) * bin.value;
  }

  // CDF at (Tobs - 1)
  return _negBinomialCdfApprox(total, p, tObs - 1).clamp(0, 1);
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
