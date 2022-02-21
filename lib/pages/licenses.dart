import 'dart:math';

import 'package:chan/pages/master_detail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

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
				child: CupertinoActivityIndicator()
			);
		}
		final packageNames = _packages.keys.toList();
		return MasterDetailPage<String>(
			id: 'licenses',
			masterBuilder: (context, selectedValue, valueSetter) => CupertinoPageScaffold(
				navigationBar: CupertinoNavigationBar(
					leading: CupertinoButton(
						padding: EdgeInsets.zero,
						minSize: 0,
						child: const Icon(CupertinoIcons.chevron_back, size: 30),
						onPressed: () => Navigator.pop(rootContext)
					),
					transitionBetweenRoutes: false,
					middle: const Text('Licenses')
				),
				child: ListView.builder(
					itemCount: packageNames.length,
					itemBuilder: (context, i) => GestureDetector(
						behavior: HitTestBehavior.opaque,
						onTap: () => valueSetter(packageNames[i]),
						child: Container(
							color: selectedValue == packageNames[i] ? CupertinoTheme.of(context).primaryColor.withOpacity(0.2) : null,
							padding: const EdgeInsets.all(16),
							child: Text(packageNames[i])
						)
					)
				)
			),
			detailBuilder: (selectedValue, poppedOut) => BuiltDetailPane(
				widget: selectedValue == null ? Container(
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					child: const Center(
						child: Text('Select a package')
					) 
				): CupertinoPageScaffold(
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: Text(selectedValue)
					),
					child: Padding(
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