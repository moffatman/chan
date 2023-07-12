import 'dart:math';

import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LicensesPage extends StatefulWidget {
	const LicensesPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
	final Map<String, List<LicenseEntry>> _packages = {};
	bool _loaded = false;

	@override
	void initState() {
		super.initState();
		LicenseRegistry.licenses.toList().then((l) {
			for (final license in l) {
				for (final package in license.packages) {
					_packages.putIfAbsent(package, () => []).add(license);
				}
			}
			setState(() {
				_loaded = true;
			});
		});
	}

	@override
	Widget build(BuildContext rootContext) {
		if (!_loaded) {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
		final packageNames = _packages.keys.toList();
		return MasterDetailPage<String>(
			id: 'licenses',
			masterBuilder: (context, selectedValue, valueSetter) => AdaptiveScaffold(
				bar: AdaptiveBar(
					leading: CupertinoButton(
						padding: EdgeInsets.zero,
						minSize: 0,
						child: const Icon(CupertinoIcons.chevron_back, size: 30),
						onPressed: () => Navigator.pop(rootContext)
					),
					title: const Text('Licenses')
				),
				body: ListView.builder(
					itemCount: packageNames.length,
					itemBuilder: (context, i) => GestureDetector(
						behavior: HitTestBehavior.opaque,
						onTap: () => valueSetter(packageNames[i]),
						child: Container(
							color: selectedValue(context, packageNames[i]) ? ChanceTheme.primaryColorOf(context).withOpacity(0.2) : null,
							padding: const EdgeInsets.all(16),
							child: Text(packageNames[i])
						)
					)
				)
			),
			detailBuilder: (selectedValue, setter, poppedOut) => BuiltDetailPane(
				widget: selectedValue == null ? const AdaptiveScaffold(
					body: Center(
						child: Text('Select a package')
					) 
				): AdaptiveScaffold(
					bar: AdaptiveBar(
						title: Text(selectedValue)
					),
					body: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 32),
						child: ListView(
							children: [
								const SizedBox(height: 32),
								for (final license in _packages[selectedValue]!) ...[
									for (final paragraph in license.paragraphs) Container(
										padding: EdgeInsets.only(left: max(0, paragraph.indent * 32), bottom: 16),
										alignment: paragraph.indent == -1 ? Alignment.center : null,
										child: Text(paragraph.text)
									)
								],
								const SizedBox(height: 32)
							]
						)
					)
				),
				pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
			)
		);
	}
}