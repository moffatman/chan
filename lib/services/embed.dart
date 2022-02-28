import 'dart:convert';

import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

	const EmbedData({
		required this.title,
		required this.provider,
		required this.author,
		required this.thumbnailUrl
	});

	@override
	String toString() => 'EmbedData(title: $title, provider: $provider, author: $author, thumbnailUrl: $thumbnailUrl)';
}

Future<EmbedData?> loadEmbedData({
	required String url,
	required BuildContext context
}) async {
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
	return null;
}