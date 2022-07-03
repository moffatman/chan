import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class TranslatedPostPage extends StatefulWidget {
	final PostSpanZoneData zone;
	final Post post;

	const TranslatedPostPage({
		required this.zone,
		required this.post,
		Key? key
	}) : super(key: key);

	@override
	createState() => _TranslatedPostPageState();
}

class _TranslatedPostPageState extends State<TranslatedPostPage> {
	Post? translatedPost;
	String? errorMessage;

	@override
	void initState() {
		super.initState();
		_translate();
	}

	void _translate() async {
		setState(() {
			translatedPost = null;
			errorMessage = null;
		});
		try {
			final translated = await translateHtml(widget.post.text);
			translatedPost = Post(
				board: widget.post.board,
				text: translated,
				name: widget.post.name,
				time: widget.post.time,
				trip: widget.post.trip,
				threadId: widget.post.threadId,
				id: widget.post.id,
				spanFormat: widget.post.spanFormat,
				flag: widget.post.flag,
				attachment: widget.post.attachment,
				attachmentDeleted: widget.post.attachmentDeleted,
				posterId: widget.post.posterId,
				foolfuukaLinkedPostThreadIds: widget.post.foolfuukaLinkedPostThreadIds,
				passSinceYear: widget.post.passSinceYear
			);
		}
		catch (e) {
			errorMessage = e.toStringDio();
		}
		setState(() {});
	}

	Widget _build() {
		if (errorMessage != null) {
			return Center(
				child: ErrorMessageCard(
					errorMessage!,
					remedies: {
						'Retry': _translate
					}
				)
			);
		}
		else if (translatedPost == null) {
			return Container(
				height: 100,
				width: double.infinity,
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				child: const CupertinoActivityIndicator()
			);
		}
		return PostRow(
			post: translatedPost!,
			onThumbnailTap: (attachment) {
				showGallery(
					context: context,
					attachments: [attachment],
					replyCounts: {
						attachment: translatedPost!.replyIds.length
					},
					initialAttachment: attachment,
					semanticParentIds: widget.zone.stackIds
				);
			}
		);
	}

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider.value(
			value: widget.zone,
			child: OverscrollModalPage(
				heightEstimate: 100.0,
				child: AnimatedSize(
					duration: const Duration(milliseconds: 100),
					child: _build()
				)
			)
		);
	}
}