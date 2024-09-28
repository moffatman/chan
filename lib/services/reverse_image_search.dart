import 'package:chan/models/attachment.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

extension on Attachment {
	String get _urlForSearch {
		if (type == AttachmentType.image) {
			return url.toString();
		}
		return thumbnailUrl.toString();
	}
}

List<ContextMenuAction> buildImageSearchActions(BuildContext context, Iterable<Attachment> possibleAttachments) {
	final withMD5 = possibleAttachments.where((a) => a.type.isImageSearchable && a.md5.isNotEmpty).toList(growable: false);
	final withThumbnail = possibleAttachments.where((a) => a.type.isImageSearchable && a.thumbnailUrl.isNotEmpty).toList(growable: false);
	return [
		if (withMD5.isNotEmpty && (context.read<ImageboardSite?>()?.supportsSearch('').options.imageMD5 ?? false)) ContextMenuAction(
			trailingIcon: Icons.image_search,
			onPressed: () async {
				final attachment = await whichAttachment(context, withMD5);
				if (context.mounted && attachment != null) {
					openSearch(context: context, query: ImageboardArchiveSearchQuery(
						imageboardKey: context.read<Imageboard>().key,
						boards: [attachment.board],
						md5: attachment.md5)
					);
				}
			},
			child: const Text('Search archives')
		),
		if (withThumbnail.isNotEmpty) ...[
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (context.mounted && attachment != null) {
						openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
							'image_url': attachment._urlForSearch,
							'safe': 'off',
							'sbisrc': 'cr_1'
						}));
					}
				},
				child: const Text('Search Google')
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (context.mounted && attachment != null) {
						openBrowser(context, Uri.https('yandex.com', '/images/search', {
							'rpt': 'imageview',
							'url': attachment._urlForSearch
						}));
					}
				},
				child: const Text('Search Yandex')
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (context.mounted && attachment != null) {
						openBrowser(context, Uri.https('saucenao.com', '/search.php', {
							'url': attachment._urlForSearch
						}));
					}
				},
				child: const Text('Search SauceNAO')
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (context.mounted && attachment != null) {
						openBrowser(context, Uri.https('iqdb.org', '/', {
							'url': attachment._urlForSearch
						}));
					}
				},
				child: const Text('Search IQDB')
			)
		]
	];
}