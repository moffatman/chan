import 'package:chan/services/persistence.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

extension _NonEmptyOrNull on String {
	String? get nonEmptyOrNull {
		if (isEmpty) {
			return null;
		}
		return this;
	}
}

typedef TabWidgetData = ({
	Widget primaryIcon,
	Widget? secondaryIcon,
	int unseenCount,
	int unseenYouCount,
	String shortTitle,
	String longTitle
});

class TabWidgetBuilder extends StatelessWidget {
	final PersistentBrowserTab tab;
	final Widget Function(BuildContext, TabWidgetData) builder;

	const TabWidgetBuilder({
		required this.tab,
		required this.builder,
		super.key
	});

	TabWidgetData _getData(context) {
		const blankIcon = Icon(CupertinoIcons.rectangle_stack);
		Widget primaryIcon = blankIcon;
		Widget? secondaryIcon;
		int unseenCount = 0;
		int unseenYouCount = 0;
		String longTitle = '';
		if (tab.imageboardKey != null) {
			if (tab.imageboard?.seemsOk == true) {
				primaryIcon = FittedBox(
					fit: BoxFit.contain,
					child: ImageboardIcon(
						imageboardKey: tab.imageboardKey,
						boardName: tab.board?.name
					)
				);
				final threadState = tab.thread == null ? null : tab.persistence?.getThreadStateIfExists(tab.thread!);
				Future.microtask(() => tab.unseen.value = threadState?.unseenReplyCount() ?? 0);
				if (threadState != null) {
					final board = tab.persistence?.getBoard(tab.thread!.board);
					final thread = threadState.thread ?? tab.imageboard?.site.getThreadFromCatalogCache(threadState.identifier);
					final attachment = thread?.attachments.tryFirst;
					longTitle = (thread?.title ?? thread?.posts_.tryFirst?.span.buildText().nonEmptyOrNull) ?? 'Thread ${tab.thread?.id}';
					if (board != null && board.icon == null) {
						longTitle = '${tab.imageboard?.site.formatBoardName(board)}: $longTitle';
					}
					if (attachment != null) {
						secondaryIcon = primaryIcon;
						primaryIcon = ClipRRect(
							borderRadius: const BorderRadius.all(Radius.circular(4)),
							child: AttachmentThumbnail(
								gaplessPlayback: true,
								fit: BoxFit.cover,
								attachment: attachment,
								width: 30,
								height: 30,
								site: tab.imageboard?.site
							)
						);
					}
					unseenYouCount = threadState.unseenReplyIdsToYouCount() ?? 0;
					unseenCount = threadState.unseenReplyCount() ?? 0;
				}
				else if (tab.board != null && tab.initialSearch != null) {
					longTitle = '${tab.imageboard?.site.formatBoardName(tab.board!)} ("${tab.initialSearch}")';
				}
			}
			else {
				primaryIcon = tab.imageboard?.boardsLoading == true ? const SizedBox(
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
		final shortTitle = (tab.board != null ? tab.imageboard?.site.formatBoardName(tab.board!) : (tab.imageboard?.site.name ?? tab.imageboardKey)) ?? 'None';
		return (
			primaryIcon: SizedBox(
				height: 30,
				width: 30,
				child: primaryIcon
			),
			secondaryIcon: secondaryIcon,
			unseenCount: unseenCount,
			unseenYouCount: unseenYouCount,
			shortTitle: shortTitle,
			longTitle: longTitle.isNotEmpty ? longTitle : shortTitle
		);
	}

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: tab,
			builder: (context, _) {
				final imageboard = tab.imageboard;
				final persistence = tab.persistence;
				if (imageboard == null || persistence == null) {
					return Builder(
						builder: (context) => builder(context, _getData(context))
					);
				}
				return AnimatedBuilder(
					animation: imageboard,
					builder: (context, _) {
						final thread = tab.thread;
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
		);
	}
}