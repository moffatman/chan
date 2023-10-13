import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide WeakMap;
import 'package:provider/provider.dart';
import 'package:weak_map/weak_map.dart';

const allPatternFields = ['text', 'subject', 'name', 'filename', 'postID', 'posterID', 'flag', 'capcode'];
const defaultPatternFields = ['subject', 'name', 'filename', 'text'];

class FilterResultType {
	final bool hide;
	final bool highlight;
	final bool pinToTop;
	final bool autoSave;
	final bool autoWatch;
	final bool notify;
	final bool collapse;

	const FilterResultType({
		this.hide = false,
		this.highlight = false,
		this.pinToTop = false,
		this.autoSave = false,
		this.autoWatch = false,
		this.notify = false,
		this.collapse = false
	});

	static const FilterResultType empty = FilterResultType();

	@override
	String toString() => 'FilterResultType(${[
		if (hide) 'hide',
		if (highlight) 'highlight',
		if (pinToTop) 'pinToTop',
		if (autoSave) 'autoSave',
		if (autoWatch) 'autoWatch',
		if (notify) 'notify',
		if (collapse) 'collapse'
	].join(', ')})';

	@override
	bool operator == (Object other) =>
		other is FilterResultType &&
		other.hide == hide &&
		other.highlight == highlight &&
		other.pinToTop == pinToTop &&
		other.autoSave == autoSave &&
		other.autoWatch == autoWatch &&
		other.notify == notify &&
		other.collapse == collapse;

	@override
	int get hashCode => Object.hash(hide, highlight, pinToTop, autoSave, autoWatch, notify, collapse);
}

class FilterResult {
	FilterResultType type;
	String reason;
	FilterResult(this.type, this.reason);

	@override
	String toString() => 'FilterResult(type: $type, reason: $reason)';
}

abstract class Filterable {
	String? getFilterFieldText(String fieldName);
	String get board;
	int get id;
	Iterable<int> get repliedToIds;
	bool get hasFile;
	bool get isThread;
	Iterable<String> get md5s;
	int get replyCount;
	bool get isDeleted;
}

class EmptyFilterable implements Filterable {
	@override
	final int id;
	const EmptyFilterable(this.id);
	@override
	String? getFilterFieldText(String fieldName) => null;

  @override
  String get board => '';

  @override
  bool get hasFile => false;

  @override
  bool get isThread => false;

	@override
	List<int> get repliedToIds => [];

	@override
	int get replyCount => 0;

	@override
	Iterable<String> get md5s => [];

	@override
	bool get isDeleted => false;
}

abstract class Filter {
	FilterResult? filter(Filterable item);

	static Filter of(BuildContext context, {bool listen = true}) {
		return (listen ? context.watch<Filter?>() : context.read<Filter?>()) ?? const DummyFilter();
	}
}

class FilterCache<T extends Filter> implements Filter {
	T wrappedFilter;
	FilterCache(this.wrappedFilter);
	// Need to use two seperate maps as we can't store null in [_cache]
	final WeakMap<Filterable, bool?> _contains = WeakMap();
	final WeakMap<Filterable, FilterResult?> _cache = WeakMap();

	@override
	FilterResult? filter(Filterable item) {
		if (_contains.get(item) != true) {
			_contains.add(key: item, value: true);
			final result = wrappedFilter.filter(item);
			if (result != null) {
				_cache.add(key: item, value: result);
			}
			return result;
		}
		return _cache.get(item);
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
	bool? threadsOnly;
	int? minRepliedTo;
	bool disabled;
	int? minReplyCount;
	int? maxReplyCount;
	bool? deletedOnly;
	CustomFilter({
		String? configuration,
		this.disabled = false,
		this.label = '',
		required this.pattern,
		this.patternFields = defaultPatternFields,
		this.outputType = const FilterResultType(hide: true),
		this.boards = const [],
		this.excludeBoards = const [],
		this.hasFile,
		this.threadsOnly,
		this.minRepliedTo,
		this.minReplyCount,
		this.maxReplyCount,
		this.deletedOnly
	}) {
		this.configuration = configuration ?? toStringConfiguration();
	}
	@override
	FilterResult? filter(Filterable item) {
		if (disabled) {
			return null;
		}
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
		if (threadsOnly == !item.isThread) {
			return null;
		}
		if (minRepliedTo != null && item.repliedToIds.length < minRepliedTo!) {
			return null;
		}
		if (minReplyCount != null && item.replyCount < minReplyCount!) {
			return null;
		}
		if (maxReplyCount != null && item.replyCount > maxReplyCount!) {
			return null;
		}
		if (deletedOnly != null && item.isDeleted != deletedOnly) {
			return null;
		}
		return FilterResult(outputType, label.isEmpty ? 'Matched "$configuration"' : '$label filter');
	}

	factory CustomFilter.fromStringConfiguration(String configuration) {
		final match = _configurationLinePattern.firstMatch(configuration);
		if (match == null) {
			throw FilterException('Invalid syntax: "$configuration"');
		}
		try {
			final filter = CustomFilter(
				configuration: configuration,
				disabled: configuration.startsWith('#'),
				label: match.group(1)!,
				pattern: RegExp(match.group(2)!, multiLine: true, caseSensitive: match.group(3) != 'i')
			);
			final separator = RegExp(r':|,');
			int i = 5;
			bool hide = true;
			bool highlight = false;
			bool pinToTop = false;
			bool autoSave = false;
			bool autoWatch = false;
			bool notify = false;
			bool collapse = false;
			while (true) {
				final s = match.group(i);
				if (s == null) {
					break;
				}
				else if (s == 'highlight') {
					highlight = true;
					hide = false;
				}
				else if (s == 'top') {
					pinToTop = true;
					hide = false;
				}
				else if (s == 'save') {
					autoSave = true;
					hide = false;
				}
				else if (s == 'watch') {
					autoWatch = true;
					hide = false;
				}
				else if (s == 'notify') {
					notify = true;
					hide = false;
				}
				else if (s == 'collapse') {
					collapse = true;
					hide = false;
				}
				else if (s == 'show') {
					hide = false;
				}
				else if (s.startsWith('type:')) {
					filter.patternFields = s.split(separator).skip(1).toList();
					if (filter.patternFields.remove('thread')) {
						// 4chan-X filters use ;type:thread instead of ;thread
						// Move it from patternFields
						filter.threadsOnly = true;
					}
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
				else if (s == 'thread' || s == 'op:only') {
					filter.threadsOnly = true;
				}
				else if (s == 'reply') {
					filter.threadsOnly = false;
				}
				else if (s == 'deleted:only') {
					filter.deletedOnly = true;
				}
				else if (s == 'deleted:no') {
					filter.deletedOnly = false;
				}
				else if (s.startsWith('minReplied')) {
					filter.minRepliedTo = int.tryParse(s.split(':')[1]);
					if (filter.minRepliedTo == null) {
						throw FilterException('Not a valid number for minReplied: "${s.split(':')[1]}"');
					}
				}
				else if (s.startsWith('minReplyCount')) {
					filter.minReplyCount = int.tryParse(s.split(':')[1]);
					if (filter.minReplyCount == null) {
						throw FilterException('Not a valid number for minReplyCount: "${s.split(':')[1]}"');
					}
				}
				else if (s.startsWith('maxReplyCount')) {
					filter.maxReplyCount = int.tryParse(s.split(':')[1]);
					if (filter.maxReplyCount == null) {
						throw FilterException('Not a valid number for maxReplyCount: "${s.split(':')[1]}"');
					}
				}
				else {
					throw FilterException('Unknown qualifier "$s"');
				}
				i += 2;
			}
			filter.outputType = FilterResultType(
				hide: hide,
				highlight: highlight,
				pinToTop: pinToTop,
				autoSave: autoSave,
				autoWatch: autoWatch,
				notify: notify,
				collapse: collapse
			);
			return filter;
		}
		catch (e) {
			if (e is FilterException) {
				rethrow;
			}
			throw FilterException(e.toString());
		}
	}

	String toStringConfiguration() {
		final out = StringBuffer();
		if (disabled) {
			out.write('#');
		}
		out.write(label);
		out.write('/');
		out.write(pattern.pattern);
		out.write('/');
		if (!pattern.isCaseSensitive) {
			out.write('i');
		}
		if (outputType.highlight) {
			out.write(';highlight');
		}
		if (outputType.pinToTop) {
			out.write(';top');
		}
		if (outputType.autoSave) {
			out.write(';save');
		}
		if (outputType.autoWatch) {
			out.write(';watch');
		}
		if (outputType.notify) {
			out.write(';notify');
		}
		if (outputType.collapse) {
			out.write(';collapse');
		}
		if (outputType == FilterResultType.empty) {
			// Kind of a dummy filter, just used to override others
			out.write(';show');
		}
		if (patternFields.isNotEmpty && !setEquals(patternFields.toSet(), defaultPatternFields.toSet())) {
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
		if (threadsOnly == true) {
			out.write(';thread');
		}
		else if (threadsOnly == false) {
			out.write(';reply');
		}
		if (minRepliedTo != null) {
			out.write(';minReplied:$minRepliedTo');
		}
		if (minReplyCount != null) {
			out.write(';minReplyCount:$minReplyCount');
		}
		if (maxReplyCount != null) {
			out.write(';maxReplyCount:$maxReplyCount');
		}
		if (deletedOnly == true) {
			out.write(';deleted:only');
		}
		else if (deletedOnly == false) {
			out.write(';deleted:no');
		}
		return out.toString();
	}

	@override
	String toString() => 'CustomFilter(configuration: $configuration, pattern: $pattern, patternFields: $patternFields, outputType: $outputType, boards: $boards, excludeBoards: $excludeBoards, hasFile: $hasFile, threadsOnly: $threadsOnly, minRepliedTo: $minRepliedTo, minReplyCount: $minReplyCount, maxReplyCount: $maxReplyCount)';

	@override
	operator == (dynamic other) => other is CustomFilter && other.configuration == configuration;

	@override
	int get hashCode => configuration.hashCode;
}

class IDFilter implements Filter {
	final List<int> hideIds;
	final List<int> showIds;
	IDFilter({
		required this.hideIds,
		required this.showIds
  });
	@override
	FilterResult? filter(Filterable item) {
		if (hideIds.contains(item.id)) {
			return FilterResult(const FilterResultType(hide: true), 'Manually hidden');
		}
		else if (showIds.contains(item.id)) {
			return FilterResult(FilterResultType.empty, 'Manually shown');
		}
		else {
			return null;
		}
	}

	@override
	String toString() => 'IDFilter(hideIds: $hideIds, showIds: $showIds)';

	@override
	operator == (Object other) => other is IDFilter && listEquals(other.hideIds, hideIds) && listEquals(other.showIds, showIds);

	@override
	int get hashCode => Object.hash(hideIds, showIds);
}

class ThreadFilter implements Filter {
	final List<int> hideIds;
	final List<int> showIds;
	final List<int> repliedToIds;
	final List<String> posterIds;
	ThreadFilter({
		required this.hideIds,
		required this.showIds,
		required this.repliedToIds,
		required this.posterIds
	});
	@override
	FilterResult? filter(Filterable item) {
		if (hideIds.contains(item.id)) {
			return FilterResult(const FilterResultType(hide: true), 'Manually hidden');
		}
		else if (showIds.contains(item.id)) {
			return FilterResult(FilterResultType.empty, 'Manually shown');
		}
		else if (repliedToIds.any(item.repliedToIds.contains)) {
			return FilterResult(const FilterResultType(hide: true), 'Replied to manually hidden');
		}
		else if (posterIds.contains(item.getFilterFieldText('posterID'))) {
			return FilterResult(const FilterResultType(hide: true), 'Posted by "${item.getFilterFieldText('posterID')}"');
		}
		else {
			return null;
		}
	}

	@override
	String toString() => 'ThreadFilter(hideIds: $hideIds, showIds: $showIds, repliedToIds: $repliedToIds, posterIds: $posterIds)';

	@override
	operator == (dynamic other) => other is ThreadFilter && listEquals(other.hideIds, hideIds) && listEquals(other.showIds, showIds) && listEquals(other.repliedToIds, repliedToIds) && listEquals(other.posterIds, posterIds);

	@override
	int get hashCode => Object.hash(hideIds, showIds, repliedToIds, posterIds);
}

class MD5Filter implements Filter {
	final Set<String> md5s;
	final bool applyToThreads;
	MD5Filter(this.md5s, this.applyToThreads);
	@override
	FilterResult? filter(Filterable item) {
		if (!applyToThreads && item.isThread) {
			return null;
		}
		return md5s.contains(item.getFilterFieldText('md5')) ?
			FilterResult(const FilterResultType(hide: true), 'Matches filtered image') : null;
	}

	@override
	String toString() => 'MD5Filter(md5s: $md5s, applyToThreads: $applyToThreads)';

	@override
	operator == (dynamic other) => other is MD5Filter && setEquals(other.md5s, md5s) && other.applyToThreads == applyToThreads;

	@override
	int get hashCode => Object.hash(md5s, applyToThreads);
}

class SearchFilter implements Filter {
	final String text;
	SearchFilter(this.text);
	@override
	FilterResult? filter(Filterable item) {
		return defaultPatternFields.map((field) {
			return item.getFilterFieldText(field) ?? '';
		}).join(' ').toLowerCase().contains(text) ? null : FilterResult(const FilterResultType(hide: true), 'Search for "$text"');
	}

	@override
	String toString() => 'SearchFilter(text: $text)';

	@override
	operator == (dynamic other) => other is SearchFilter && other.text == text;

	@override
	int get hashCode => text.hashCode;
}

class FilterGroup<T extends Filter> implements Filter {
	final List<T> filters;
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

final _configurationLinePattern = RegExp(r'^#?([^\/]*)\/(.*)\/(i?)(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?$');

FilterGroup<CustomFilter> makeFilter(String configuration) {
	final filters = <CustomFilter>[];
	for (final pair in configuration.split('\n').indexed) {
		final (i, line) = pair;
		if (line.isEmpty) {
			continue;
		}
		try {
			filters.add(CustomFilter.fromStringConfiguration(line));
		}
		catch (e) {
			// It might be a filter, or it could just be a comment
			if (!line.startsWith('#')) {
				throw Exception('Problem with filter on line ${i + 1} "$line"\n${e.toString()}');
			}
		}
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
			value: FilterCache(FilterGroup([FilterCache(filter), Filter.of(context)])),
			child: child
		);
	}
}