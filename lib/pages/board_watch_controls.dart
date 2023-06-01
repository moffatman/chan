import 'package:chan/models/board.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum _BoardWatchingStatus {
	off,
	threadsOnly,
	threadsAndPosts
}

class BoardWatchControlsPage extends StatefulWidget {
	final Imageboard imageboard;
	final ImageboardBoard board;

	const BoardWatchControlsPage({
		required this.imageboard,
		required this.board,
		super.key
	});

	@override
	createState() => _BoardWatchControlsPage();
}

@override
class _BoardWatchControlsPage extends State<BoardWatchControlsPage> {

	@override
	Widget build(BuildContext context) {
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
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				alignment: Alignment.center,
				child: ConstrainedBox(
					constraints: const BoxConstraints(
						maxWidth: 500
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Center(
								child: Text('Push Notifications for /${widget.board.name}/', style: const TextStyle(
									fontSize: 18
								))
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
										backgroundColor: context.select<EffectiveSettings, Color>((s) => s.theme.barColor),
										backgroundColorActivated: context.select<EffectiveSettings, Color>((s) => s.theme.primaryColorWithBrightness(0.5)),
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