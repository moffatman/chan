import 'dart:convert';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
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
	final site = context.read<ImageboardSite?>();
	final withMD5 = possibleAttachments.where((a) => a.type.isImageSearchable && a.md5.isNotEmpty).toList(growable: false);
	final withThumbnail = possibleAttachments.where((a) => a.type.isImageSearchable && a.thumbnailUrl.isNotEmpty).toList(growable: false);
	return [
		if (withMD5.isNotEmpty && (site?.supportsSearch('').options.imageMD5 ?? false)) ContextMenuAction(
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
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (!context.mounted || attachment == null) {
						return;
					}
					final queryHash = await modalLoad<String>(context, 'Searching TinEye...', (_) async {
						final response = await Settings.instance.client.postUri(Uri.https('tineye.com', '/api/v1/result_json/'), data: FormData.fromMap({
							'url': attachment._urlForSearch
						}), options: Options(responseType: ResponseType.json));
						return response.data['query_hash'] as String;
					}, wait: const Duration(milliseconds: 150), cancellable: true);
					if (context.mounted) {
						openBrowser(context, Uri.https('tineye.com', '/search/$queryHash'));
					}
				},
				child: const Text('Search TinEye')
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (context.mounted && attachment != null) {
						openBrowser(context, Uri.https('trace.moe', '/', {
							'url': attachment._urlForSearch
						}));
					}
				},
				child: const Text('Search trace.moe')
			),
			ContextMenuAction(
				trailingIcon: Icons.image_search,
				onPressed: () async {
					final attachment = await whichAttachment(context, withThumbnail);
					if (!context.mounted || attachment == null) {
						return;
					}
					final String b64Blob;
					final String ext;
					final file = (await getCachedImageFile(attachment._urlForSearch)) ?? (await getCachedImageFile(attachment._urlForSearch));
					if (file != null) {
						b64Blob = await base64.encoder.bind(file.openRead()).join('');
						ext = file.path.split('.').last;
					}
					else {
						final response = await (site?.client ?? Settings.instance.client).get(attachment._urlForSearch, options: Options(
							responseType: ResponseType.stream
						));
						b64Blob = await base64.encoder.bind((response.data as ResponseBody).stream).join('');
						ext = attachment._urlForSearch.split('.').last;
					}
					if (!context.mounted) {
						return;
					}
					final resultHash = await modalLoad<String>(context, 'Searching lenso.ai...', (_) async {
						final response = await Settings.instance.client.postUri(Uri.https('lenso.ai', '/api/upload'), data: FormData.fromMap({
							'image': 'data:image/$ext;base64,$b64Blob'
						}), options: Options(responseType: ResponseType.json));
						return response.data['id'] as String;
					}, wait: const Duration(milliseconds: 150), cancellable: true);
					if (context.mounted) {
						openBrowser(context, Uri.https('lenso.ai', '/en/results/$resultHash'));
					}
				},
				child: const Text('Search lenso.ai')
			),
		]
	];
}