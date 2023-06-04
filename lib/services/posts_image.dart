import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_switch2.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

int _countDescendants(PostSpanZoneData zone, Post post) {
	int visit(int id) {
		int x = 0;
		for (final r in zone.findPost(id)?.replyIds ?? []) {
			x += 1 + visit(r);
		}
		return x;
	}
	return visit(post.id);
}

Future<ShareablePostsStyle?> composeShareablePostsStyle({
	required BuildContext context,
	required Post post
}) async {
	final settings = context.read<EffectiveSettings>();
	final zone = context.read<PostSpanZoneData>();
	final lastStyle = settings.lastShareablePostsStyle;
	bool useTree = lastStyle.useTree;
	int parentDepth = lastStyle.parentDepth;
	int childDepth = lastStyle.childDepth;
	double width = lastStyle.width;
	String? overrideThemeKey = lastStyle.overrideThemeKey;
	bool expandPrimaryImage = lastStyle.expandPrimaryImage;
	bool revealYourPosts = lastStyle.revealYourPosts;
	bool includeFooter = lastStyle.includeFooter;
	if (!useTree && childDepth > 1) {
		childDepth = 1;
	}
	final ok = await showCupertinoDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => StatefulBuilder(
			builder: (context, setDialogState) => CupertinoAlertDialog2(
				title: const Text('Export Settings'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const SizedBox(height: 16),
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: () async {
								final newKey = await selectThemeKey(
									context: context,
									title: 'Pick theme',
									currentKey: overrideThemeKey ?? settings.themeKey,
									allowEditing: false
								);
								if (newKey != null) {
									overrideThemeKey = newKey;
									setDialogState(() {});
								}
							},
							child: Container(
								decoration: BoxDecoration(
									borderRadius: const BorderRadius.all(Radius.circular(8)),
									color: (settings.themes[overrideThemeKey] ?? settings.theme).backgroundColor
								),
								padding: const EdgeInsets.all(16),
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(CupertinoIcons.paintbrush, color: (settings.themes[overrideThemeKey] ?? settings.theme).primaryColor),
										const SizedBox(width: 4),
										Flexible(
											child: Text('Theme: ${overrideThemeKey ?? settings.themeKey}', style: TextStyle(
												color: (settings.themes[overrideThemeKey] ?? settings.theme).primaryColor
											))
										)
									]
								)
							)
						),
						const SizedBox(height: 8),
						Row(
							children: [
								const Icon(CupertinoIcons.list_bullet_indent),
								const SizedBox(width: 8),
								const Expanded(
									child: Text('Tree mode', textAlign: TextAlign.left)
								),
								CupertinoSwitch2(
									value: useTree,
									onChanged: (x) => setDialogState(() {
										useTree = x;
										if (!useTree && childDepth > 1) {
											childDepth = 1;
										}
									})
								)
							]
						),
						const SizedBox(height: 8),
						Row(
							children: [
								const Icon(CupertinoIcons.rectangle_arrow_up_right_arrow_down_left),
								const SizedBox(width: 8),
								const Expanded(
									child: Text('Expand image', textAlign: TextAlign.left)
								),
								CupertinoSwitch2(
									value: post.attachments.any((a) => a.type == AttachmentType.image) ? expandPrimaryImage : false,
									onChanged: post.attachments.any((a) => a.type == AttachmentType.image) ? (x) => setDialogState(() {
										expandPrimaryImage = x;
									}) : null
								)
							]
						),
						const SizedBox(height: 8),
						Row(
							children: [
								const Icon(CupertinoIcons.person),
								const SizedBox(width: 8),
								const Expanded(
									child: Text('Reveal your posts', textAlign: TextAlign.left)
								),
								CupertinoSwitch2(
									value: revealYourPosts,
									onChanged: (x) => setDialogState(() {
										revealYourPosts = x;
									})
								)
							]
						),
						const SizedBox(height: 8),
						Row(
							children: [
								const Icon(CupertinoIcons.link),
								const SizedBox(width: 8),
								const Expanded(
									child: Text('Include footer', textAlign: TextAlign.left)
								),
								CupertinoSwitch2(
									value: includeFooter,
									onChanged: (x) => setDialogState(() {
										includeFooter = x;
									})
								)
							]
						),
						const SizedBox(height: 8),
						const Text('Include ancestors'),
						const SizedBox(height: 8),
						Opacity(
							opacity: post.repliedToIds.isEmpty ? 0.5 : 1,
							child: IgnorePointer(
								ignoring: post.repliedToIds.isEmpty,
								child: CupertinoSegmentedControl(
									children: {
										0: const Padding(
											padding: EdgeInsets.all(8),
											child: Text('None')
										),
										1: const Padding(
											padding: EdgeInsets.all(8),
											child: Text('Just one', textAlign: TextAlign.center)
										),
										2: Padding(
											padding: const EdgeInsets.all(8),
											child: Text('All (${findAncestors(zone, post).length})')
										)
									},
									groupValue: parentDepth,
									onValueChanged: (x) => setDialogState(() {
										parentDepth = x;
									})
								)
							)
						),
						const SizedBox(height: 8),
						const Text('Include replies'),
						const SizedBox(height: 8),
						Opacity(
							opacity: post.replyIds.isEmpty ? 0.5 : 1,
							child: IgnorePointer(
								ignoring: post.replyIds.isEmpty,
								child: CupertinoSegmentedControl(
									children: useTree ? {
										0: const Padding(
											padding: EdgeInsets.all(8),
											child: Text('None')
										),
										1: Padding(
											padding: const EdgeInsets.all(8),
											child: Text('Direct only (${post.replyIds.length})', textAlign: TextAlign.center)
										),
										2: Padding(
											padding: const EdgeInsets.all(8),
											child: Text('Full tree (${_countDescendants(zone, post)})', textAlign: TextAlign.center)
										)
									} : {
										0: const Padding(
											padding: EdgeInsets.all(8),
											child: Text('No')
										),
										1: Padding(
											padding: const EdgeInsets.all(8),
											child: Text('Yes (${post.replyIds.length})')
										)
									},
									groupValue: childDepth,
									onValueChanged: (x) => setDialogState(() {
										childDepth = x;
									})
								)
							)
						),
						const SizedBox(height: 8),
						const Text('Image max width'),
						const SizedBox(height: 8),
						Row(
							children: [
								Expanded(
									child: Text('${width.round()} px')
								),
								CupertinoButton(
									padding: EdgeInsets.zero,
									onPressed: width <= 300 ? null : () {
										width -= 50;
										setDialogState(() {});
									},
									child: const Icon(CupertinoIcons.minus)
								),
								CupertinoButton(
									padding: EdgeInsets.zero,
									onPressed: width >= 1500 ? null : () {
										width += 50;
										setDialogState(() {});
									},
									child: const Icon(CupertinoIcons.plus)
								)
							]
						)
					]
				),
				actions: [
					CupertinoDialogAction2(
						onPressed: () => Navigator.pop(context, false),
						child: const Text('Cancel')
					),
					CupertinoDialogAction2(
						isDefaultAction: true,
						onPressed: () => Navigator.pop(context, true),
						child: const Text('Export'),
					)
				]
			)
		)
	);
	if (ok ?? false) {
		return settings.lastShareablePostsStyle = ShareablePostsStyle(
			useTree: useTree,
			overrideThemeKey: overrideThemeKey,
			parentDepth: parentDepth,
			childDepth: childDepth,
			width: width,
			expandPrimaryImage: expandPrimaryImage,
			revealYourPosts: revealYourPosts,
			includeFooter: includeFooter
		);
	}
	return null;
}

Future<File> sharePostsAsImage({
	required BuildContext context,
	required int primaryPostId,
	required ShareablePostsStyle style
}) async {
	final controller = ScreenshotController();
	final mediaQueryData = context.getInheritedWidgetOfExactType<MediaQuery>()!.data;
	final img = await controller.captureFromLongWidget(
		MediaQuery(
			data: mediaQueryData.copyWith(devicePixelRatio: 1),
			child: FilterZone(
				filter: Filter.of(context, listen: false),
				child: MultiProvider(
					providers: [
						ChangeNotifierProvider.value(value: context.read<EffectiveSettings>()),
						ChangeNotifierProvider.value(value: context.read<Imageboard>()),
						Provider.value(value: context.read<ImageboardSite>()),
						ChangeNotifierProvider.value(value: context.read<Persistence>()),
						ChangeNotifierProvider.value(value: context.read<ThreadWatcher>()),
						Provider.value(value: context.read<Notifications>()),
						ChangeNotifierProvider.value(value: context.read<PostSpanZoneData>())
					],
					child: ChanceTheme(
						themeKey: style.overrideThemeKey ?? ChanceTheme.keyOf(context, listen: false),
						child: ShareablePosts(
							primaryPostId: primaryPostId,
							style: style
						)
					)
				)
			)
		),
		pixelRatio: mediaQueryData.devicePixelRatio,
		delay: const Duration(milliseconds: 500)
	);
	final file = File('${Persistence.documentsDirectory.path}/screenshot.png');
	await file.writeAsBytes(img);
	return file;
}