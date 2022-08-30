import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

const allPatternFields = ['text', 'subject', 'name', 'filename', 'postID', 'posterID', 'flag'];
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
	Iterable<int> get repliedToIds;
	bool get hasFile;
	bool get isThread;
	Iterable<String> get md5s;
}

abstract class Filter {
	FilterResult? filter(Filterable item);

	static Filter of(BuildContext context, {bool listen = true}) {
		return (listen ? context.watch<Filter?>() : context.read<Filter?>()) ?? const DummyFilter();
	}
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
	late final String configuration;
	final String label;
	final RegExp pattern;
	List<String> patternFields;
	FilterResultType outputType;
	List<String> boards;
	List<String> excludeBoards;
	bool? hasFile;
	bool threadOnly;
	int? minRepliedTo;
	CustomFilter({
		String? configuration,
		this.label = '',
		required this.pattern,
		this.patternFields = defaultPatternFields,
		this.outputType = FilterResultType.hide,
		this.boards = const [],
		this.excludeBoards = const [],
		this.hasFile,
		this.threadOnly = false,
		this.minRepliedTo
	}) {
		this.configuration = configuration ?? toStringConfiguration();
	}
	@override
	FilterResult? filter(Filterable item) {
		if (pattern.pattern.isNotEmpty) {
			bool matches = false;
			for (final field in patternFields) {
				if (pattern.hasMatch(item.getFilterFieldText(field) ?? '')) {
					matches = true;
					break;
				}
			}
			if (!matches) {
				return null;
			}
		}
		if (boards.isNotEmpty && !boards.contains(item.board)) {
			return null;
		}
		if (excludeBoards.isNotEmpty && excludeBoards.contains(item.board)) {
			return null;
		}
		if (hasFile != null && hasFile != item.hasFile) {
			return null;
		}
		if (threadOnly == true && !item.isThread) {
			return null;
		}
		if (minRepliedTo != null && item.repliedToIds.length < minRepliedTo!) {
			return null;
		}
		return FilterResult(outputType, label.isEmpty ? 'Matched "$configuration"' : '$label filter');
	}

	factory CustomFilter.fromStringConfiguration(String configuration) {
		print(configuration);
		final match = _configurationLinePattern.firstMatch(configuration);
		if (match == null) {
			throw FilterException('Invalid syntax: "$configuration"');
		}
		final filter = CustomFilter(
			configuration: configuration,
			label: match.group(1)!,
			pattern: RegExp(match.group(2)!, multiLine: true, caseSensitive: match.group(3) != 'i')
		);
		final separator = RegExp(r':|,');
		int i = 5;
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
				filter.patternFields = s.split(separator).skip(1).toList();
			}
			else if (s.startsWith('boards:')) {
				filter.boards = s.split(separator).skip(1).toList();
			}
			else if (s.startsWith('exclude:')) {
				filter.excludeBoards = s.split(separator).skip(1).toList();
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
			else if (s.startsWith('minReplied')) {
				filter.minRepliedTo = int.tryParse(s.split(':')[1]);
				if (filter.minRepliedTo == null) {
					throw FilterException('Not a valid number for minReplied: "${s.split(':')[1]}"');
				}
			}
			else {
				throw FilterException('Unknown qualifier "$s"');
			}
			i += 2;
		}
		return filter;
	}

	String toStringConfiguration() {
		final out = StringBuffer();
		out.write(label);
		out.write('/');
		out.write(pattern.pattern);
		out.write('/');
		if (outputType == FilterResultType.highlight) {
			out.write(';highlight');
		}
		else if (outputType == FilterResultType.pinToTop) {
			out.write(';top');
		}
		else if (outputType == FilterResultType.autoSave) {
			out.write(';save');
		}
		if (patternFields != defaultPatternFields && patternFields.isNotEmpty) {
			out.write(';type:${patternFields.join(',')}');
		}
		if (boards.isNotEmpty) {
			out.write(';boards:${boards.join(',')}');
		}
		if (excludeBoards.isNotEmpty) {
			out.write(';exclude:${excludeBoards.join(',')}');
		}
		if (hasFile == true) {
			out.write(';file:only');
		}
		else if (hasFile == false) {
			out.write(';file:no');
		}
		if (threadOnly) {
			out.write(';thread');
		}
		if (minRepliedTo != null) {
			out.write(';minReplied:$minRepliedTo');
		}
		return out.toString();
	}

	@override
	String toString() => 'CustomFilter(configuration: $configuration, pattern: $pattern, patternFields: $patternFields, outputType: $outputType, boards: $boards, excludeBoards: $excludeBoards, hasFile: $hasFile, threadOnly: $threadOnly, minRepliedTo: $minRepliedTo)';

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
		if (ids.contains(item.id)) {
			return FilterResult(FilterResultType.hide, 'Manually hidden');
		}
		else {
			return null;
		}
	}

	@override
	String toString() => 'IDFilter(ids: $ids)';

	@override
	operator == (dynamic other) => other is IDFilter && listEquals(other.ids, ids);

	@override
	int get hashCode => ids.hashCode;
}

class ThreadFilter implements Filter {
	final List<int> ids;
	final List<int> repliedToIds;
	final List<String> posterIds;
	ThreadFilter(this.ids, this.repliedToIds, this.posterIds);
	@override
	FilterResult? filter(Filterable item) {
		if (ids.contains(item.id)) {
			return FilterResult(FilterResultType.hide, 'Manually hidden');
		}
		else if (repliedToIds.any(item.repliedToIds.contains)) {
			return FilterResult(FilterResultType.hide, 'Replied to manually hidden');
		}
		else if (posterIds.contains(item.getFilterFieldText('posterID'))) {
			return FilterResult(FilterResultType.hide, 'Posted by "${item.getFilterFieldText('posterID')}"');
		}
		else {
			return null;
		}
	}

	@override
	String toString() => 'ThreadFilter(ids: $ids, repliedToIds: $repliedToIds, posterIds: $posterIds)';

	@override
	operator == (dynamic other) => other is ThreadFilter && listEquals(other.ids, ids) && listEquals(other.repliedToIds, repliedToIds) && listEquals(other.posterIds, posterIds);

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

final _configurationLinePattern = RegExp(r'^([^\/]*)\/(.*)\/(i?)(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?$');

FilterGroup makeFilter(String configuration) {
	final filters = <Filter>[];
	for (final line in configuration.split('\n')) {
		if (line.startsWith('#') || line.isEmpty) {
			continue;
		}
		filters.add(CustomFilter.fromStringConfiguration(line));
	}
	return FilterGroup(filters);
}

class FilterZone extends StatelessWidget {
	final Filter filter;
	final Widget child;

	const FilterZone({
		required this.filter,
		required this.child,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Provider<Filter>.value(
			value: FilterCache(FilterGroup([Filter.of(context), FilterCache(filter)])),
			child: child
		);
	}
}