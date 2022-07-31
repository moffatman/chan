import 'dart:convert';

import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

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
	if (url.startsWith('chance://site/') || url.startsWith('chance://theme')) {
		return true;
	}
	if (kDebugMode) {
		return context.read<EffectiveSettings>().embedRegexes.any((regex) => regex.hasMatch(url));
	}
	else {
		return await compute<_EmbedParam, bool>((param) {
			return param.regexes.any((regex) => regex.hasMatch(param.url));
		}, _EmbedParam(
			regexes: context.read<EffectiveSettings>().embedRegexes,
			url: url
		));
	}
}

String? findEmbedUrl({
	required String text,
	required BuildContext context
}) {
	for (final regex in context.read<EffectiveSettings>().embedRegexes) {
		final match = regex.firstMatch(text);
		if (match != null) {
			return match.group(0);
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
	if (url.startsWith('chance://site/')) {
		try {
			final response = await Dio().get(url.replaceFirst('chance://', '$contentSettingsApiRoot/'));
			print(response);
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
		final response = await context.read<ImageboardSite>().client.get('https://noembed.com/embed', queryParameters: {
			'url': url
		});
		if (response.data != null) {
			final data = jsonDecode(response.data);
			return EmbedData(
				title: data['title'],
				provider: data['provider_name'],
				author: data['author_name'],
				thumbnailUrl: data['thumbnail_url']
			);
		}
	}
	return null;
}