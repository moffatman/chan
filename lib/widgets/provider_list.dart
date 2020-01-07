import 'package:chan/widgets/data_stream_provider.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProviderList<T> extends StatelessWidget {
	final Widget Function(BuildContext context, T value) builder;
	final Future<List<T>> Function() listUpdater;
	final String title;

	ProviderList({
		@required this.builder,
		@required this.listUpdater,
		@required this.title,
	});


	@override
	Widget build(BuildContext context) {
		return DataProvider<List<T>>(
			id: title,
			updater: listUpdater,
			initialValue: [],
			placeholder: (BuildContext context, value) {
				return Center(
					child: CupertinoActivityIndicator()
				);
			},
			builder: (BuildContext context, List<T> values, Future<void> Function() requestUpdate) {
				return CustomScrollView(
					physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), 
					slivers: [
						CupertinoSliverNavigationBar(
							largeTitle: Text(title),
							heroTag: title
						),
						CupertinoSliverRefreshControl(
							onRefresh: requestUpdate,
						),
						SliverSafeArea(
							top: false,
							sliver: SliverList(
								delegate: SliverChildBuilderDelegate(
									(context, i) {
										if (i % 2 == 0) {
											return builder(context, values[i ~/ 2]);
										}
										else {
											return Divider(
												height: 0
											);
										}
									},
									childCount: (values.length * 2) - 1
								)
							)
						)
					]
				);
			},
			onError: alertError
		);
	}
}