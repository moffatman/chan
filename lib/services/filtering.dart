import 'package:flutter/foundation.dart';

const defaultPatternFields = ['subject', 'name', 'filename', 'text'];

enum FilterResultType {
	hide,
	highlight,
	pinToTop,
	autoSave
}

class FilterResult {
	FilterResultType type;
	String reason;
	FilterResult(this.type, this.reason);
}

abstract class Filterable {
	String? getFilterFieldText(String fieldName);
	String get board;
	int get id;
	bool get hasFile;
	bool get isThread;
}

abstract class Filter {
	FilterResult? filter(Filterable item);
}

class FilterCache implements Filter {
	Filter wrappedFilter;
	FilterCache(this.wrappedFilter);
	final Map<Filterable, FilterResult?> _cache = {};
	void setFilter(Filter newFilter) {
		if (newFilter != wrappedFilter) {
			_cache.clear();
		}
		wrappedFilter = newFilter;
	}

	@override
	FilterResult? filter(Filterable item) {
		return _cache.putIfAbsent(item, () => wrappedFilter.filter(item));
	}

	@override
	String toString() => 'FilterCache($wrappedFilter)';

	@override
	bool operator ==(dynamic other) => other is FilterCache && other.wrappedFilter == wrappedFilter;

	@override
	int get hashCode => wrappedFilter.hashCode;
}

class CustomFilter implements Filter {
	final String configuration;
	final RegExp pattern;
	List<String> patternFields;
	FilterResultType outputType;
	List<String>? boards;
	List<String>? excludeBoards;
	bool? hasFile;
	bool? threadOnly;
	CustomFilter({
		required this.configuration,
		required this.pattern,
		this.patternFields = defaultPatternFields,
		this.outputType = FilterResultType.hide
	});
	@override
	FilterResult? filter(Filterable item) {
		bool matches = false;
		for (final field in patternFields) {
			if (pattern.hasMatch(item.getFilterFieldText(field) ?? '')) {
				matches = true;
				break;
			}
		}
		if (boards != null && !boards!.contains(item.board)) {
			return null;
		}
		if (excludeBoards != null && excludeBoards!.contains(item.board)) {
			return null;
		}
		if (hasFile != null && hasFile != item.hasFile) {
			return null;
		}
		if (threadOnly == true && !item.isThread) {
			return null;
		}
		return matches ? FilterResult(outputType, 'Matched "$configuration"') : null;
	}

	@override
	String toString() => 'CustomFilter(configuration: $configuration, pattern: $pattern, patternFields: $patternFields, outputType: $outputType, boards: $boards, excludeBoards: $excludeBoards, hasFile: $hasFile, threadOnly: $threadOnly)';

	@override
	operator == (dynamic other) => other is CustomFilter && other.configuration == configuration;

	@override
	int get hashCode => configuration.hashCode;
}

class IDFilter implements Filter {
	final List<int> ids;
	IDFilter(this.ids);
	@override
	FilterResult? filter(Filterable item) {
		return ids.contains(item.id) ? FilterResult(FilterResultType.hide, 'Manually hidden') : null;
	}

	@override
	String toString() => 'IDFilter(ids: $ids)';

	@override
	operator == (dynamic other) => other is IDFilter && listEquals(other.ids, ids);

	@override
	int get hashCode => ids.hashCode;
}

class MD5Filter implements Filter {
	final Set<String> md5s;
	MD5Filter(this.md5s);
	@override
	FilterResult? filter(Filterable item) {
		return md5s.contains(item.getFilterFieldText('md5')) ?
			FilterResult(FilterResultType.hide, 'Matches filtered image') : null;
	}

	@override
	String toString() => 'MD5Filter(md5s: $md5s)';

	@override
	operator == (dynamic other) => other is MD5Filter && setEquals(other.md5s, md5s);

	@override
	int get hashCode => md5s.hashCode;
}

class SearchFilter implements Filter {
	final String text;
	SearchFilter(this.text);
	@override
	FilterResult? filter(Filterable item) {
		return defaultPatternFields.map((field) {
			return item.getFilterFieldText(field) ?? '';
		}).join(' ').toLowerCase().contains(text) ? null : FilterResult(FilterResultType.hide, 'Search for "$text"');
	}

	@override
	String toString() => 'SearchFilter(text: $text)';

	@override
	operator == (dynamic other) => other is SearchFilter && other.text == text;

	@override
	int get hashCode => text.hashCode;
}

class FilterGroup implements Filter {
	final List<Filter> filters;
	FilterGroup(this.filters);
	@override
	FilterResult? filter(Filterable item) {
		for (final filter in filters) {
			final result = filter.filter(item);
			if (result != null) {
				return result;
			}
		}
		return null;
	}

	@override
	String toString() => 'FilterGroup(filters: $filters)';

	@override
	operator == (dynamic other) => other is FilterGroup && listEquals(other.filters, filters);

	@override
	int get hashCode => filters.hashCode;
}

class DummyFilter implements Filter {
	const DummyFilter();
	@override
	FilterResult? filter(Filterable item) => null;

	@override
	operator == (dynamic other) => other is DummyFilter;

	@override
	int get hashCode => 0;
}

class FilterException implements Exception {
	String message;
	FilterException(this.message);

	@override
	String toString() => 'Filter Error: $message';
}

final _configurationLinePattern = RegExp(r'^\/(.*)\/(i?)(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?$');

Filter _makeFilter(String configuration) {
	final match = _configurationLinePattern.firstMatch(configuration);
	if (match == null) {
		throw FilterException('Invalid syntax: "$configuration"');
	}
	final filter = CustomFilter(
		configuration: configuration,
		pattern: RegExp(match.group(1)!, multiLine: true, caseSensitive: match.group(2) != 'i')
	);
	int i = 4;
	while (true) {
		final s = match.group(i);
		if (s == null) {
			break;
		}
		else if (s == 'highlight') {
			filter.outputType = FilterResultType.highlight;
		}
		else if (s == 'top') {
			filter.outputType = FilterResultType.pinToTop;
		}
		else if (s == 'save') {
			filter.outputType = FilterResultType.autoSave;	
		}
		else if (s.startsWith('type:')) {
			filter.patternFields = s.split(':').skip(1).toList();
		}
		else if (s.startsWith('boards:')) {
			filter.boards = s.split(':').skip(1).toList();
		}
		else if (s.startsWith('exclude:')) {
			filter.excludeBoards = s.split(':').skip(1).toList();
		}
		else if (s == 'file:only') {
			filter.hasFile = true;
		}
		else if (s == 'file:no') {
			filter.hasFile = false;
		}
		else if (s == 'thread') {
			filter.threadOnly = true;
		}
		else {
			throw FilterException('Unknown qualifier "$s"');
		}
		i += 2;
	}
	return filter;
}

Filter makeFilter(String configuration) {
	final filters = <Filter>[];
	for (final line in configuration.split('\n')) {
		if (line.startsWith('#') || line.isEmpty) {
			continue;
		}
		filters.add(_makeFilter(line));
	}
	return FilterGroup(filters);
}