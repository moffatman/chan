import 'dart:convert';

import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:linkify/linkify.dart';
import 'package:provider/provider.dart';

final _youtubeShortsRegex = RegExp(r'youtube.com\/shorts\/([^?]+)');

class _EmbedParam {
	final List<RegExp> regexes;
	final String url;
	const _EmbedParam({
		required this.regexes,
		required this.url
	});
}

Future<bool> embedPossible({
	required String url,
	required BuildContext context
}) async {
	final embedRegexes = context.read<EffectiveSettings>().embedRegexes;
	if (url.startsWith('chance://site/') || url.startsWith('chance://theme')) {
		return true;
	}
	if (url.contains('twitter.com/') || url.contains('imgur.com/') || url.contains('imgur.io/')) {
		return false;
	}
	if (url.contains('youtube.com/shorts')) {
		return true;
	}
	if (await ImageboardRegistry.instance.decodeUrl(url) != null) {
		return true;
	}
	if (kDebugMode) {
		return embedRegexes.any((regex) => regex.hasMatch(url));
	}
	else {
		return await compute<_EmbedParam, bool>((param) {
			return param.regexes.any((regex) => regex.hasMatch(param.url));
		}, _EmbedParam(
			regexes: embedRegexes,
			url: url
		));
	}
}

String? findEmbedUrl({
	required String text,
	required BuildContext context
}) {
	for (final element in linkify(text, linkifiers: const [LooseUrlLinkifier()])) {
		if (element is UrlElement) {
			for (final regex in context.read<EffectiveSettings>().embedRegexes) {
				final match = regex.firstMatch(element.url);
				if (match != null) {
					return match.group(0);
				}
			}
		}
	}
	return null;
}


class EmbedData {
	final String? title;
	final String? provider;
	final String? author;
	final String? thumbnailUrl;
	final Widget? thumbnailWidget;

	const EmbedData({
		required this.title,
		required this.provider,
		required this.author,
		required this.thumbnailUrl,
		this.thumbnailWidget
	});

	@override
	String toString() => 'EmbedData(title: $title, provider: $provider, author: $author, thumbnailUrl: $thumbnailUrl, thumbnailWidget: $thumbnailWidget)';
}

Future<EmbedData?> loadEmbedData({
	required String url,
	required BuildContext context
}) async {
	final client = context.read<ImageboardSite>().client;
	if (url.startsWith('chance://site/')) {
		try {
			final response = await Dio().get(url.replaceFirst('chance://', '$contentSettingsApiRoot/'));
			if (response.data['data'] == null) {
				throw Exception(response.data['error'] ?? 'Unknown error');
			}
			final site = makeSite(response.data['data']);
			return EmbedData(
				title: site.name,
				provider: site.baseUrl,
				author: null,
				thumbnailUrl: site.iconUrl.toString()
			);
		}
		catch (e) {
			return EmbedData(
				title: 'Unsupported site: ${url.substring(14)}',
				provider: e.toStringDio(),
				author: null,
				thumbnailUrl: null,
				thumbnailWidget: const Icon(CupertinoIcons.exclamationmark_triangle_fill)
			);
		}
	}
	else if (url.startsWith('chance://theme')) {
		final uri = Uri.parse(url);
		final theme = SavedTheme.decode(uri.queryParameters['data']!);
		return EmbedData(
			title: uri.queryParameters['name']!,
			provider: 'Chance Theme',
			author: null,
			thumbnailUrl: null,
			thumbnailWidget: SizedBox(
				width: 75,
				height: 75,
				child: SavedThemeThumbnail(
					theme: theme
				)
			)
		);
	}
	else {
		final target = await ImageboardRegistry.instance.decodeUrl(url);
		if (target != null && target.$2.threadId != null) {
			Thread? thread;
			try {
				if (!target.$3) {
					thread = await target.$1.site.getThread(target.$2.threadIdentifier!, interactive: false);
				}
			}
			on ThreadNotFoundException {
				// Maybe dead?
			}
			thread ??= await target.$1.site.getThreadFromArchive(target.$2.threadIdentifier!, interactive: false);
			final post = thread.posts_.tryFirstWhere((p) => p.id == target.$2.postId) ?? thread.posts_.first;
			if (post.id == post.threadId) {
				return EmbedData(
					title: thread.title,
					provider: target.$1.site.name,
					author: post.name,
					thumbnailUrl: post.attachments.tryFirst?.thumbnailUrl ?? thread.attachments.tryFirst?.thumbnailUrl
				);
			}
			String title = thread.title ?? thread.posts_.first.span.buildText();
			if (title.length > 50) {
				final space = title.lastIndexOf(' ', 50);
				title = '${title.substring(0, space == -1 ? 47 : space)}...';
			}
			return EmbedData(
				title: 'Reply to "$title"',
				provider: '${target.$1.site.name} (${target.$1.site.formatBoardName(thread.board)})',
				author: post.name,
				thumbnailUrl: post.attachments.tryFirst?.thumbnailUrl ?? thread.attachments.tryFirst?.thumbnailUrl
			);
		}
		final youtubeShortsMatch = _youtubeShortsRegex.firstMatch(url);
		if (youtubeShortsMatch != null) {
			url = 'https://www.youtube.com/watch?v=${youtubeShortsMatch.group(1)}';
		}
		final response = await client.get('https://noembed.com/embed', queryParameters: {
			'url': url
		});
		if (response.data != null) {
			final data = jsonDecode(response.data);
			String? thumbnailUrl = data['thumbnail_url'];
			if (thumbnailUrl?.startsWith('//') == true) {
				thumbnailUrl = 'https:$thumbnailUrl';
			}
			return EmbedData(
				title: data['title'],
				provider: data['provider_name'],
				author: data['author_name'],
				thumbnailUrl: thumbnailUrl
			);
		}
	}
	return null;
}