import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

typedef ThreadWidgetData = ({
	Widget primaryIcon,
	Widget? secondaryIcon,
	int unseenCount,
	int unseenYouCount,
	String shortTitle,
	String longTitle,
	bool isArchived,
	Imageboard? imageboard,
	PersistentThreadState? threadState
});

class ThreadWidgetBuilder extends StatelessWidget {
	final Imageboard? imageboard;
	final Persistence? persistence;
	final String? boardName;
	final ThreadIdentifier? thread;
	final Widget Function(BuildContext, ThreadWidgetData) builder;
	final String? initialSearch;

	const ThreadWidgetBuilder({
		required this.imageboard,
		required this.persistence,
		required this.builder,
		required this.boardName,
		required this.thread,
		this.initialSearch,
		super.key
	});

	ThreadWidgetData _getData(context) {
		const blankIcon = Icon(CupertinoIcons.rectangle_stack);
		Widget primaryIcon = blankIcon;
		Widget? secondaryIcon;
		int unseenCount = 0;
		int unseenYouCount = 0;
		String longTitle = '';
		PersistentThreadState? threadState;
		bool isArchived = false;
		if (imageboard != null) {
			final persistence = this.persistence ?? imageboard?.persistence;
			if (imageboard?.seemsOk == true) {
				primaryIcon = FittedBox(
					fit: BoxFit.contain,
					child: ImageboardIcon(
						imageboardKey: imageboard?.key,
						boardName: boardName
					)
				);
				threadState = thread == null ? null : persistence?.getThreadStateIfExists(thread!);
				if (threadState != null) {
					final board = persistence?.getBoard(this.thread!.board);
					final thread = threadState.thread ?? imageboard?.site.getThreadFromCatalogCache(threadState.identifier);
					isArchived = thread?.isArchived ?? threadState.useArchive;
					final attachment = thread?.attachments.tryFirst;
					longTitle = (thread?.title ?? thread?.posts_.tryFirst?.span.buildText().nonEmptyOrNull) ?? 'Thread ${threadState.id}';
					if (board != null && board.icon == null && board.name.isNotEmpty) {
						longTitle = '${imageboard?.site.formatBoardName(board.name)}: $longTitle';
					}
					if (attachment != null) {
						secondaryIcon = primaryIcon;
						primaryIcon = ClipRRect(
							borderRadius: const BorderRadius.all(Radius.circular(4)),
							child: AttachmentThumbnail(
								gaplessPlayback: true,
								fit: BoxFit.cover,
								attachment: attachment,
								mayObscure: true,
								width: 30,
								height: 30,
								site: imageboard?.site,
								onLoadError: (e, st) {
									imageboard?.threadWatcher.fixBrokenThread(threadState!.identifier);
								},
							)
						);
					}
					unseenYouCount = threadState.unseenReplyIdsToYouCount() ?? 0;
					unseenCount = threadState.unseenReplyCount() ?? 0;
				}
				else if (boardName != null && initialSearch != null) {
					longTitle = '${imageboard?.site.formatBoardName(boardName!)} ("$initialSearch")';
				}
			}
			else {
				primaryIcon = imageboard?.boardsLoading == true ? const SizedBox(
					width: 30,
					height: 30,
					child: CircularProgressIndicator.adaptive()
				) : const SizedBox(
					width: 30,
					height: 30,
					child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
				);
			}
		}
		final shortTitle = (boardName != null ? imageboard?.site.formatBoardName(boardName!) : imageboard?.site.name) ?? 'None';
		return (
			primaryIcon: SizedBox(
				height: 30,
				width: 30,
				child: primaryIcon
			),
			isArchived: isArchived,
			secondaryIcon: secondaryIcon,
			unseenCount: unseenCount,
			unseenYouCount: unseenYouCount,
			shortTitle: shortTitle,
			longTitle: longTitle.isNotEmpty ? longTitle : shortTitle,
			imageboard: imageboard,
			threadState: threadState
		);
	}

	@override
	Widget build(BuildContext context) {
		final imageboard = this.imageboard;
		final persistence = this.persistence ?? imageboard?.persistence;
		if (imageboard == null || persistence == null) {
			return Builder(
				builder: (context) => builder(context, _getData(context))
			);
		}
		return AnimatedBuilder(
			animation: imageboard,
			builder: (context, _) {
				final thread = this.thread;
				if (thread == null) {
					return Builder(
						builder: (context) => builder(context, _getData(context))
					);
				}
				return AnimatedBuilder(
					animation: persistence.listenForPersistentThreadStateChanges(thread),
					builder: (context, _) {
						final threadState = persistence.getThreadStateIfExists(thread);
						if (threadState == null) {
							return Builder(
								builder: (context) => builder(context, _getData(context))
							);
						}
						else {
							return AnimatedBuilder(
								animation: threadState,
								builder: (context, _) => builder(context, _getData(context))
							);
						}
					}
				);
			}
		);
	}
}

class TabWidgetBuilder extends StatelessWidget {
	final PersistentBrowserTab tab;
	final Widget Function(BuildContext, ThreadWidgetData) builder;

	const TabWidgetBuilder({
		required this.tab,
		required this.builder,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: tab,
			builder: (context, _) {
				return ThreadWidgetBuilder(
					imageboard: tab.imageboard,
					persistence: tab.persistence,
					boardName: tab.board,
					thread: tab.thread,
					initialSearch: tab.initialSearch,
					builder: (context, data) {
						Future.microtask(() => tab.unseen.value = data.unseenCount);
						Widget primaryIcon = data.primaryIcon;
						if (tab.incognito) {
							primaryIcon = Stack(
								alignment: Alignment.center,
								clipBehavior: Clip.none,
								children: [
									primaryIcon,
									Positioned(
										bottom: -5,
										child: DecoratedBox(
											decoration: BoxDecoration(
												color: ChanceTheme.primaryColorOf(context),
												borderRadius: BorderRadius.circular(8)
											),
											child: Padding(
												padding: const EdgeInsets.symmetric(horizontal: 4),
												child: Icon(CupertinoIcons.eyeglasses, size: 20, color: ChanceTheme.barColorOf(context))
											)
										)
									)
								]
							);
						}
						return builder(context, (
							longTitle: data.longTitle,
							shortTitle: data.shortTitle,
							primaryIcon: primaryIcon,
							secondaryIcon: data.secondaryIcon,
							unseenCount: data.unseenCount,
							unseenYouCount: data.unseenYouCount,
							imageboard: data.imageboard,
							threadState: data.threadState,
							isArchived: data.isArchived
						));
					}
				);
			}
		);
	}
}