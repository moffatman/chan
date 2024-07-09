import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:normal/normal.dart';

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
			final last = codeUnits.last;
			int i;
			for (i = 1; codeUnits[codeUnits.length - i] == last && i < codeUnits.length; i++) {
				// Go through each matching digits
			}
			i--; // we exit loop on i == too far by one
			bins.update(i, (x) => x + 1, ifAbsent: () => 1);
		}
	}
	return (total, bins);
}

double? calculateLuck() {
	final (total, bins) = _calculate();
	if (total == 0) {
		return null;
	}
	const p = 0.9; // Odds of singles
	return 1 - Normal.cdf(bins[1] ?? 0, mean: p * total, variance: total * (p * (1 - p)));
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
