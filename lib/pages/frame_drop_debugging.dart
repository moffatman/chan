import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class FrameDropDebuggingPage extends StatefulWidget {
	final ImageboardSite site;
	const FrameDropDebuggingPage({
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _FrameDropDebuggingPageState();
}

class _FrameDropDebuggingPageState extends State<FrameDropDebuggingPage> {
	@override
	Widget build(BuildContext context) {
		final persistence = context.watch<Persistence>();
		final settings = context.watch<EffectiveSettings>();
		return RefreshableList<Thread>(
			gridDelegate: settings.useCatalogGrid ? SliverGridDelegateWithMaxCrossAxisExtent(
				maxCrossAxisExtent: settings.catalogGridWidth,
				childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
			) : null,
			filterableAdapter: (t) => t,
			listUpdater: () async {
				final thread = await widget.site.getThread(ThreadIdentifier('g', 85712241));
				return List.generate(150, (i) => thread);
			},
			id: 'debugging frame drops',
			itemBuilder: (context, thread) {
				final browserState = persistence.browserState;
				return ContextMenu(
					actions: [
						if (persistence.getThreadStateIfExists(thread.identifier)?.savedTime != null) ContextMenuAction(
							child: const Text('Un-save thread'),
							trailingIcon: CupertinoIcons.bookmark_fill,
							onPressed: () {
								final threadState = persistence.getThreadState(thread.identifier);
								threadState.savedTime = null;
								threadState.save();
								setState(() {});
							}
						)
						else ContextMenuAction(
							child: const Text('Save thread'),
							trailingIcon: CupertinoIcons.bookmark,
							onPressed: () {
								final threadState = persistence.getThreadState(thread.identifier);
								threadState.thread = thread;
								threadState.savedTime = DateTime.now();
								threadState.save();
								setState(() {});
							}
						),
						if (browserState.isThreadHidden(thread.board, thread.id)) ContextMenuAction(
							child: const Text('Unhide thread'),
							trailingIcon: CupertinoIcons.eye_slash_fill,
							onPressed: () {
								browserState.unHideThread(thread.board, thread.id);
								persistence.didUpdateBrowserState();
								setState(() {});
							}
						)
						else ContextMenuAction(
							child: const Text('Hide thread'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								browserState.hideThread(thread.board, thread.id);
								persistence.didUpdateBrowserState();
								setState(() {});
							}
						)
					],
					maxHeight: 125,
					child:  GestureDetector(
						child: ThreadRow(
							contentFocus: settings.useCatalogGrid,
							thread: thread,
							isSelected: false,
							semanticParentIds: const [-99],
							onThumbnailTap: (initialAttachment) {
								showGallery(
									context: context,
									attachments: [initialAttachment],
									initialAttachment: initialAttachment,
									semanticParentIds: [-99],
									heroOtherEndIsBoxFitCover: settings.useCatalogGrid
								);
							}
						),
						onTap: () {
							Navigator.of(context).push(FullWidthCupertinoPageRoute(
								builder: (ctx) => ThreadPage(
									thread: thread.identifier,
									boardSemanticId: -99,
								),
								showAnimations: context.read<EffectiveSettings>().showAnimations
							));
						}
					)
				);
			},
			filterHint: 'Search in board'
		);
	}
}