import 'package:chan/widgets/util.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;
import 'package:provider/provider.dart';

class MasterDetailPage<T> extends StatefulWidget {
	final double twoPaneBreakpoint;
	final Widget Function(BuildContext context, T? selectedValue, ValueChanged<T> valueSetter) masterBuilder;
	final Widget Function(BuildContext context, T? selectedValue) detailBuilder;
	MasterDetailPage({
		required this.masterBuilder,
		required this.detailBuilder,
		this.twoPaneBreakpoint = 700
	});
	@override
	createState() => _MasterDetailPageState<T>();
}

class _MasterDetailPageState<T> extends State<MasterDetailPage<T>> {
	final _masterKey = GlobalKey<NavigatorState>();
	final _detailKey = GlobalKey<NavigatorState>();
	T? selectedValue;
	late bool onePane;

	void _valueSetter(T value) {
		setState(() {
			if (onePane) {
				_masterKey.currentState!.push(cpr.CupertinoPageRoute(
					builder: (ctx) => widget.detailBuilder(ctx, value)
				));
			}
			else {
				_detailKey.currentState!.popUntil((route) => route.isFirst);
			}
			selectedValue = value;
		});
	}

	@override
	Widget build(BuildContext context) {
		onePane = MediaQuery.of(context).size.width < widget.twoPaneBreakpoint;
		final masterNavigator = Provider.value(
			value: _masterKey,
			child: Navigator(
				key: _masterKey,
				initialRoute: '/',
				onGenerateRoute: (RouteSettings settings) {
					return TransparentRoute(
						builder: (context) => widget.masterBuilder(context, onePane ? null : selectedValue, _valueSetter)
					);
				}
			)
		);
		final detailNavigator = Provider.value(
			value: _detailKey,
			child: Navigator(
				key: _detailKey,
				initialRoute: '/',
				onGenerateRoute: (RouteSettings settings) {
					return cpr.CupertinoPageRoute(
						builder: (context) => widget.detailBuilder(context, selectedValue),
						settings: settings
					);
				}
			)
		);
		if (onePane) {
			return masterNavigator;
		}
		else {
			return Row(
				children: [
					Flexible(
						flex: 1,
						child: masterNavigator
					),
					VerticalDivider(
						width: 0,
						color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
					),
					Flexible(
						flex: 3,
						child: detailNavigator
					)
				]
			);
		}
	}
}