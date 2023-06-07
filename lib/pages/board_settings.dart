import 'package:chan/models/board.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_adaptive_segmented_control.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum _BoardWatchingStatus {
	off,
	threadsOnly,
	threadsAndPosts
}

class BoardSettingsPage extends StatefulWidget {
	final Imageboard imageboard;
	final ImageboardBoard board;

	const BoardSettingsPage({
		required this.imageboard,
		required this.board,
		super.key
	});

	@override
	createState() => _BoardSettingsPageState();
}

@override
class _BoardSettingsPageState extends State<BoardSettingsPage> {

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		_BoardWatchingStatus status;
		final watch = widget.imageboard.notifications.boardWatches.tryFirstWhere((w) => w.board == widget.board.name);
		if (watch == null) {
			status = _BoardWatchingStatus.off;
		}
		else {
			status = watch.threadsOnly ? _BoardWatchingStatus.threadsOnly : _BoardWatchingStatus.threadsAndPosts;
		}
		return OverscrollModalPage(	
			child: Container(
				width: double.infinity,
				padding: const EdgeInsets.all(16),
				color: ChanceTheme.backgroundColorOf(context),
				alignment: Alignment.center,
				child: ConstrainedBox(
					constraints: const BoxConstraints(
						maxWidth: 500
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									ImageboardIcon(
										imageboardKey: widget.imageboard.key,
										boardName: widget.board.name,
										size: 20
									),
									const SizedBox(width: 8),
									Text(
										'${widget.imageboard.site.formatBoardName(widget.board)} Settings',
										style: const TextStyle(
											fontSize: 18,
											fontWeight: FontWeight.bold
										)
									)
								]
							),
							const SizedBox(height: 16),
							const Center(
								child: Text('Catalog Layout')
							),
							const SizedBox(height: 16),
							CupertinoAdaptiveSegmentedControl(
								groupValue: widget.imageboard.persistence.browserState.useCatalogGridPerBoard[widget.board.name].value,
								knownWidth: MediaQuery.sizeOf(context).width,
								children: {
									NullSafeOptional.false_: (CupertinoIcons.rectangle_grid_1x2, 'Rows'),
									NullSafeOptional.null_: (null, 'Default (${(widget.imageboard.persistence.browserState.useCatalogGrid ?? settings.useCatalogGrid) ? 'Grid' : 'Rows'})'),
									NullSafeOptional.true_: (CupertinoIcons.rectangle_split_3x3, 'Grid'),
								},
								onValueChanged: (v) {
									final newValue = v.value;
									if (newValue != null) {
										widget.imageboard.persistence.browserState.useCatalogGridPerBoard[widget.board.name] = newValue;
									}
									else {
										widget.imageboard.persistence.browserState.useCatalogGridPerBoard.remove(widget.board.name);
									}
									widget.imageboard.persistence.didUpdateBrowserState();
									setState(() {});
								},
							),
							const SizedBox(height: 16),
							const Center(
								child: Text('Push Notifications')
							),
							const SizedBox(height: 16),
							ClipRRect(
								borderRadius: BorderRadius.circular(8),
								child: CupertinoListSection(
									topMargin: 0,
									margin: EdgeInsets.zero,
									children: const [
										(_BoardWatchingStatus.off, 'Off'),
										(_BoardWatchingStatus.threadsOnly, 'Threads only'),
										(_BoardWatchingStatus.threadsAndPosts, 'All posts (not reliable)')
									].map((v) => CupertinoListTile(
										title: Text(v.$2),
										backgroundColor: ChanceTheme.barColorOf(context),
										backgroundColorActivated: ChanceTheme.primaryColorWithBrightnessOf(context, 0.5),
										trailing: status == v.$1 ? const Icon(CupertinoIcons.check_mark, size: 18) : const SizedBox.shrink(),
										onTap: () {
											if (v.$1 != _BoardWatchingStatus.off) {
												widget.imageboard.notifications.subscribeToBoard(
													boardName: widget.board.name,
													threadsOnly: v.$1 == _BoardWatchingStatus.threadsOnly
												);
											}
											else {
												widget.imageboard.notifications.unsubscribeFromBoard(widget.board.name);
											}
											setState(() {});
										}
									)).toList()
								)
							),
							const SizedBox(height: 16),
							FilterEditor(
								showRegex: false,
								forBoard: widget.board.name,
								blankFilter: CustomFilter(
									pattern: RegExp('', caseSensitive: false),
									boards: [widget.board.name],
									outputType: const FilterResultType(
										notify: true
									)
								)
							)
						]
					)
				)
			)
		);
	}
}