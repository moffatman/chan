import 'package:chan/main.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabsPage extends StatelessWidget {
	const TabsPage({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final theme = context.watch<SavedTheme>();
		final tabs = context.watch<ChanTabs>();
		final settings = context.watch<Settings>();
		final list = DrawerList.tabs(
			tabs: tabs,
			settings: settings,
			afterUse: () => Navigator.pop(context),
			menuAxisDirection: AxisDirection.up
		);
		return OverscrollModalPage.sliver(
			sliver: DecoratedSliver(
				// To avoid bleeding transparency between items
				decoration: BoxDecoration(
					color: theme.backgroundColor
				),
				sliver: SliverMainAxisGroup(
					slivers: [
						SliverToBoxAdapter(
							child: Container(
								color: theme.barColor,
								padding: const EdgeInsets.all(16),
								alignment: Alignment.center,
								child: const Text('Tabs')
							)
						),
						if (list.pinFirstItem) SliverToBoxAdapter(
							child: Material(
								child: Builder(
									builder: (context) => list.itemBuilder(context, 0)
								)
							)
						),
						SliverReorderableList(
							itemCount: list.pinFirstItem ? list.list.length - 1 : list.list.length,
							onReorder: (oldIndex, newIndex) {
								final oldI = list.pinFirstItem ? oldIndex + 1 : oldIndex;
								final newI = list.pinFirstItem ? newIndex + 1 : newIndex;
								list.onReorder?.call(oldI, newI);
							},
							itemBuilder: (context, index) {
								final i = list.pinFirstItem ? index + 1 : index;
								return Material(
									key: ValueKey(list.list[i]),
									child: list.itemBuilder(context, i)
								);
							}
						),
						if (list.footer != null) SliverToBoxAdapter(
							child: Material(
								child: list.footer
							)
						)
					]
				)
			)
		);
	}
}