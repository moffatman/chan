
import 'dart:io';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/text_highlighting.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum DraftPostWidgetOrigin {
	none,
	inCurrentThread,
	elsewhere
}

class DraftPostWidget extends StatelessWidget {
	final Imageboard imageboard;
	final DraftPost post;
	final DraftPostWidgetOrigin origin;
	final DateTime? time;
	final int? id;

	const DraftPostWidget({
		required this.imageboard,
		required this.post,
		required this.origin,
		this.time,
		this.id,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final thread = imageboard.persistence.getThreadStateIfExists(post.thread)?.thread;
		final isArchived = thread?.isArchived ?? false;
		String? title = (thread?.title ?? thread?.posts_.tryFirst?.span.buildText().nonEmptyOrNull);
		if ((title?.length ?? 0) > 25) {
			int firstSpaceBefore25 = title?.lastIndexOf(' ', 25) ?? 0;
			if (firstSpaceBefore25 < 10) {
				// Don't make it way too short
				firstSpaceBefore25 = 25;
			}
			title = '${title?.substring(0, firstSpaceBefore25)}...';
		}
		final file = post.file;
		return Row(
			children: [
				if (file != null) Padding(
					padding: const EdgeInsets.only(right: 12),
					child: ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: ConstrainedBox(
							constraints: const BoxConstraints(
								maxWidth: 64,
								maxHeight: 64
							),
							child: SavedAttachmentThumbnail(
								file: File(file)
							)
						)
					)
				),
				Expanded(
					child: Builder(
						builder: (context) => Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text.rich(
									buildDraftInfoRow(
										imageboard: imageboard,
										post: post,
										settings: context.watch<Settings>(),
										theme: context.watch<SavedTheme>(),
										time: time,
										id: id
									)
								),
								Padding(
									padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
									child: Text.rich(
										TextSpan(
											children: [
											buildHighlightedCommentTextSpan(
												text: post.text
											),
											if (origin != DraftPostWidgetOrigin.none) TextSpan(
												children: [
													if (post.text.isNotEmpty) const TextSpan(text: '\n'),
													if (origin == DraftPostWidgetOrigin.inCurrentThread)
														const TextSpan(text: 'In current thread')
													else if (post.threadId == null)
														TextSpan(text: 'New thread on ${imageboard.site.formatBoardName(post.board)}')
													else ...[
														const TextSpan(text: 'In '),
														TextSpan(
															text: '>>>${imageboard.site.formatBoardNameWithoutTrailingSlash(post.board)}/${post.threadId}${isArchived ? ' (Archived)' : ''}',
															style: TextStyle(
																color: Settings.instance.theme.secondaryColor,
																decoration: TextDecoration.underline
															)
														),
														if (title != null) TextSpan(text: ' ($title)')
													]
												],
												style: TextStyle(color: Settings.instance.theme.primaryColorWithBrightness(0.5))
											)
										],
										style: TextStyle(color: Settings.instance.theme.primaryColor)
										)
									)
								)
							]
						)
					)
				)
			]
		);
	}
}