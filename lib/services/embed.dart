import 'dart:convert';

import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:linkify/linkify.dart';

final _youtubeShortsRegex = RegExp(r'youtube.com\/shorts\/([^?]+)');

class _EmbedParam {
	final List<RegExp> regexes;
	final String url;
	const _EmbedParam({
		required this.regexes,
		required this.url
	});
}

Future<bool> embedPossible(String url) async {
	final embedRegexes = Settings.instance.embedRegexes;
	if (url.startsWith('chance://site/') || url.startsWith('chance://theme')) {
		return true;
	}
	if (url.contains('instagram.com/p/')) {
		return true;
	}
	// Twitter should be contained in embedRegexes already 
	if (url.contains('/x.com/')) {
		return true;
	}
	if (url.contains('imgur.com/') || url.contains('imgur.io/')) {
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

Future<String?>? findEmbedUrl(String text) async {
	for (final element in linkify(text, linkifiers: const [LooseUrlLinkifier()])) {
		if (element is UrlElement) {
			if (await embedPossible(element.url)) {
				return element.url;
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

final _twitterPattern = RegExp(r'(?:x|twitter)\.com/[^/]+/status/(\d+)');

Future<EmbedData?> _loadTwitter(String id) async {
	final response = await Settings.instance.client.getUri(Uri.https('api.vxtwitter.com', '/_/status/$id'));
	return EmbedData(
		title: response.data['text'],
		provider: 'Twitter',
		author: response.data['user_name'],
		thumbnailUrl: switch ((response.data['media_extended'] as List?)?.tryFirst?['thumbnail_url']) {
			String url => generateThumbnailerForUrl(Uri.parse(url)).toString(),
			_ => response.data['user_profile_image_url']
		}
	);
}

final _instagramPattern = RegExp(r'instagram\.com/p/([^/]+)');

Future<EmbedData?> _loadInstagram(String id) async {
	final response = await Settings.instance.client.getUri(Uri.https('www.instagram.com', '/p/$id/embed/captioned'));
	final document = parse(response.data);
	final caption = document.querySelector('.Caption');
	final src = document.querySelector('.EmbeddedMediaImage')?.attributes['src'];
	if (caption == null || src == null) {
		return null;
	}
	return EmbedData(
		author: caption.querySelector('.CaptionUsername')!.text,
		title: caption.nodes.map((e) {
			if (e is dom.Element) {
				if (e.classes.contains('CaptionUsername') || e.classes.contains('CaptionComments')) {
					return '';
				}
				if (e.localName == 'br') {
					return '\n';
				}
			}
			return e.text ?? '';
		}).join('').trim(),
		provider: 'Instagram',
		thumbnailUrl: generateThumbnailerForUrl(Uri.parse(src)).toString()
	);
}

Future<EmbedData?> loadEmbedData(String url) async {
	if (url.startsWith('chance://site/')) {
		try {
			Map? data = JsonCache.instance.sites.value?[Uri.parse(url).pathSegments.tryFirst];
			if (data == null) {
				throw Exception('No such site ${Uri.parse(url).pathSegments}');
			}
			final site = makeSite(data);
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
		final twitterMatch = _twitterPattern.firstMatch(url);
		if (twitterMatch != null) {
			return _loadTwitter(twitterMatch.group(1)!);
		}
		final instagramMatch = _instagramPattern.firstMatch(url);
		if (instagramMatch != null) {
			return _loadInstagram(instagramMatch.group(1)!);
		}
		final target = await ImageboardRegistry.instance.decodeUrl(url);
		if (target != null && target.$2.threadId != null) {
			Thread? thread;
			try {
				if (!target.$3) {
					thread = await target.$1.site.getThread(target.$2.threadIdentifier!, priority: RequestPriority.cosmetic);
				}
			}
			on ThreadNotFoundException {
				// Maybe dead?
			}
			thread ??= await target.$1.site.getThreadFromArchive(target.$2.threadIdentifier!, priority: RequestPriority.cosmetic);
			final post = thread.posts_.tryFirstWhere((p) => p.id == target.$2.postId) ?? thread.posts_.first;
			if (post.id == post.threadId) {
				return EmbedData(
					title: thread.title,
					provider: target.$1.site.name,
					author: target.$1.site.formatUsername(post.name),
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
				author: target.$1.site.formatUsername(post.name),
				thumbnailUrl: post.attachments.tryFirst?.thumbnailUrl ?? thread.attachments.tryFirst?.thumbnailUrl
			);
		}
		final youtubeShortsMatch = _youtubeShortsRegex.firstMatch(url);
		if (youtubeShortsMatch != null) {
			url = 'https://www.youtube.com/watch?v=${youtubeShortsMatch.group(1)}';
		}
		final response = await Settings.instance.client.get('https://noembed.com/embed', queryParameters: {
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