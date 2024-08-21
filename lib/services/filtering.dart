import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide WeakMap;
import 'package:provider/provider.dart';
import 'package:weak_map/weak_map.dart';

const allPatternFields = ['text', 'subject', 'name', 'filename', 'dimensions', 'postID', 'posterID', 'flag', 'capcode', 'trip'];
const defaultPatternFields = ['subject', 'name', 'filename', 'text'];

class AutoWatchType {
	final bool? push;

	const AutoWatchType({
		required this.push
	});

	bool get hasProperties => push != null;

	@override
	String toString() => 'AutoWatchType(push: $push)';
}

class FilterResultType {
	final bool hide;
	final bool highlight;
	final bool pinToTop;
	final bool autoSave;
	final AutoWatchType? autoWatch;
	final bool notify;
	final bool collapse;
	final bool hideReplies;
	final bool hideReplyChains;

	const FilterResultType({
		this.hide = false,
		this.highlight = false,
		this.pinToTop = false,
		this.autoSave = false,
		this.autoWatch,
		this.notify = false,
		this.collapse = false,
		this.hideReplies = false,
		this.hideReplyChains = false
	});

	static const FilterResultType empty = FilterResultType();

	@override
	String toString() => 'FilterResultType(${[
		if (hide) 'hide',
		if (highlight) 'highlight',
		if (pinToTop) 'pinToTop',
		if (autoSave) 'autoSave',
		if (autoWatch != null) autoWatch.toString(),
		if (notify) 'notify',
		if (collapse) 'collapse',
		if (hideReplies) 'hideReplies',
		if (hideReplyChains) 'hideReplyChains'
	].join(', ')})';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is FilterResultType &&
		other.hide == hide &&
		other.highlight == highlight &&
		other.pinToTop == pinToTop &&
		other.autoSave == autoSave &&
		other.autoWatch == autoWatch &&
		other.notify == notify &&
		other.collapse == collapse &&
		other.hideReplies == hideReplies &&
		other.hideReplyChains == hideReplyChains;

	@override
	int get hashCode => Object.hash(hide, highlight, pinToTop, autoSave, autoWatch, notify, collapse, hideReplies, hideReplyChains);
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

	bool get supportsMetaFilter;
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
	bool get supportsMetaFilter => wrappedFilter.supportsMetaFilter;

	@override
	String toString() => 'FilterCache($wrappedFilter)';

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is FilterCache &&
		other.wrappedFilter == wrappedFilter;

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
		if (pattern.pattern.isNotEmpty) {
			if (!patternFields.any((field) => pattern.hasMatch(item.getFilterFieldText(field) ?? ''))) {
				return null;
			}
		}
		return FilterResult(outputType, label.isEmpty ? 'Matched "$configuration"' : '$label filter');
	}

	static final _separatorPattern = RegExp(r':|,');

	factory CustomFilter.fromStringConfiguration(String configuration) {
		final match = _configurationLinePattern.firstMatch(configuration);
		if (match == null) {
			throw FilterException('Invalid syntax: "$configuration"');
		}
		try {
			final flags = match.group(3) ?? '';
			final filter = CustomFilter(
				configuration: configuration,
				disabled: configuration.startsWith('#'),
				label: match.group(1)!,
				pattern: RegExp(match.group(2)!, multiLine: !flags.contains('s'), caseSensitive: !flags.contains('i'))
			);
			int i = 5;
			bool hide = true;
			bool highlight = false;
			bool pinToTop = false;
			bool autoSave = false;
			AutoWatchType? autoWatch;
			bool notify = false;
			bool collapse = false;
			bool hideReplies = false;
			bool hideReplyChains = false;
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
				else if (s == 'watch' || s.startsWith('watch:')) {
					bool? push;
					for (final part in s.split(_separatorPattern).skip(1)) {
						if (part == 'push') {
							push = true;
						}
						else if (part == 'noPush') {
							push = false;
						}
						else {
							throw FilterException('Unknown watch qualifier: $part');
						}
					}
					autoWatch = AutoWatchType(
						push: push
					);
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
				else if (s == 'hideReplies') {
					hideReplies = true;
				}
				else if (s == 'hideReplyChains') {
					hideReplyChains = true;
				}
				else if (s.startsWith('type:')) {
					filter.patternFields = s.split(_separatorPattern).skip(1).toList();
					if (filter.patternFields.remove('thread')) {
						// 4chan-X filters use ;type:thread instead of ;thread
						// Move it from patternFields
						filter.threadsOnly = true;
					}
				}
				else if (s.startsWith('boards:') || s.startsWith('board:')) {
					if (filter.boards.isEmpty) {
						// It could be initialized to a const list, better just replace it
						filter.boards = s.split(_separatorPattern).skip(1).toList();
					}
					else {
						filter.boards.addAll(s.split(_separatorPattern).skip(1));
					}
				}
				else if (s.startsWith('exclude:')) {
					filter.excludeBoards = s.split(_separatorPattern).skip(1).toList();
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
				else if (s == 'reply' || s == 'op:no') {
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
				collapse: collapse,
				hideReplies: hideReplies,
				hideReplyChains: hideReplyChains
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
		if (!pattern.isMultiLine) {
			out.write('s');
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
		if (outputType.autoWatch != null) {
			out.write(';watch');
			if (outputType.autoWatch?.hasProperties ?? false) {
				out.write(':');
				if (outputType.autoWatch?.push == true) {
					out.write('push');
				}
				else if (outputType.autoWatch?.push == false) {
					out.write('noPush');
				}
			}
		}
		if (outputType.notify) {
			out.write(';notify');
		}
		if (outputType.collapse) {
			out.write(';collapse');
		}
		if (outputType.hideReplies) {
			out.write(';hideReplies');
		}
		if (outputType.hideReplyChains) {
			out.write(';hideReplyChains');
		}
		if (outputType == FilterResultType.empty ||
		    outputType == const FilterResultType(hideReplies: true) ||
				outputType == const FilterResultType(hideReplyChains: true)) {
			// Kind of a dummy filter, just used to override others
			// Also lets you hideReplies without hiding primary post
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
	bool get supportsMetaFilter => outputType.hideReplies || outputType.hideReplyChains;

	@override
	String toString() => 'CustomFilter(configuration: $configuration, pattern: $pattern, patternFields: $patternFields, outputType: $outputType, boards: $boards, excludeBoards: $excludeBoards, hasFile: $hasFile, threadsOnly: $threadsOnly, minRepliedTo: $minRepliedTo, minReplyCount: $minReplyCount, maxReplyCount: $maxReplyCount)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CustomFilter &&
		other.configuration == configuration;

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
	bool get supportsMetaFilter => false;

	@override
	String toString() => 'IDFilter(hideIds: $hideIds, showIds: $showIds)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is IDFilter &&
		listEquals(other.hideIds, hideIds) &&
		listEquals(other.showIds, showIds);

	@override
	int get hashCode => Object.hash(Object.hashAll(hideIds), Object.hashAll(showIds));
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
	bool get supportsMetaFilter => false;

	@override
	String toString() => 'ThreadFilter(hideIds: $hideIds, showIds: $showIds, repliedToIds: $repliedToIds, posterIds: $posterIds)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ThreadFilter &&
		listEquals(other.hideIds, hideIds) &&
		listEquals(other.showIds, showIds) &&
		listEquals(other.repliedToIds, repliedToIds) &&
		listEquals(other.posterIds, posterIds);

	@override
	int get hashCode => Object.hash(Object.hashAll(hideIds), Object.hashAll(showIds), Object.hashAll(repliedToIds), Object.hashAll(posterIds));
}

class MD5Filter implements Filter {
	final Set<String> md5s;
	final bool applyToThreads;
	final int depth; 
	MD5Filter(this.md5s, this.applyToThreads, this.depth);
	@override
	FilterResult? filter(Filterable item) {
		if (!applyToThreads && item.isThread) {
			return null;
		}
		return md5s.contains(item.getFilterFieldText('md5')) ?
			FilterResult(
				FilterResultType(
					hide: true,
					hideReplies: depth > 0,
					hideReplyChains: depth > 1
				),
				'Matches filtered image')
			: null;
	}

	@override
	bool get supportsMetaFilter => depth > 0;

	@override
	String toString() => 'MD5Filter(md5s: $md5s, applyToThreads: $applyToThreads, depth: $depth)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is MD5Filter &&
		setEquals(other.md5s, md5s) &&
		other.applyToThreads == applyToThreads &&
		other.depth == depth;

	@override
	int get hashCode => Object.hash(Object.hashAllUnordered(md5s), applyToThreads, depth);
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
	bool get supportsMetaFilter => filters.any((f) => f.supportsMetaFilter);

	@override
	String toString() => 'FilterGroup(filters: $filters)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is FilterGroup &&
		listEquals(other.filters, filters);

	@override
	int get hashCode => Object.hashAll(filters);
}

class DummyFilter implements Filter {
	const DummyFilter();
	@override
	FilterResult? filter(Filterable item) => null;

	@override
	bool get supportsMetaFilter => false;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is DummyFilter;

	@override
	int get hashCode => 0;
}

class FilterException implements Exception {
	String message;
	FilterException(this.message);

	@override
	String toString() => 'Filter Error: $message';
}

final _configurationLinePattern = RegExp(r'^#?([^\/]*)\/(.*)\/([is]*)(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?(;([^;]+))?$');

FilterGroup<CustomFilter> makeFilter(String configuration) {
	final filters = <CustomFilter>[];
	for (final (i, line) in configuration.split(lineSeparatorPattern).indexed) {
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

class MetaFilter implements Filter {
	final toxicRepliedToIds = <int, FilterResult>{};
	final treeToxicRepliedToIds = <int, FilterResult>{};

	MetaFilter(Filter parent, List<Filterable>? list) {
		if (list == null || !parent.supportsMetaFilter) {
			// Nothing to do
			return;
		}
		// Not all sites ensure strictly chronological sorting
		// This is important so that only one pass is needed to tree-hide
		final sorted = list.toList();
		sorted.sort((a, b) => a.id.compareTo(b.id));

		for (final item in sorted) {
			final result = parent.filter(item);
			if (result != null && result.type.hideReplyChains) {
				treeToxicRepliedToIds[item.id] = result;
			}
			else if (result != null && result.type.hideReplies) {
				toxicRepliedToIds[item.id] = result;
			}
			if (item.repliedToIds.any(treeToxicRepliedToIds.containsKey)) {
				final match = item.repliedToIds.tryMapOnce((id) => treeToxicRepliedToIds[id]);
				if (match != null) {
					treeToxicRepliedToIds[item.id] = match;
				}
			}
		}
	}

	@override
	FilterResult? filter(Filterable item) {
		if (toxicRepliedToIds.isEmpty && treeToxicRepliedToIds.isEmpty) {
			return null;
		}
		for (final id in item.repliedToIds) {
			final match = toxicRepliedToIds[id];
			if (match != null) {
				return FilterResult(const FilterResultType(hide: true), 'Replied to $id (${match.reason})');
			}
			final treeMatch = treeToxicRepliedToIds[id];
			if (treeMatch != null) {
				return FilterResult(const FilterResultType(hide: true), 'In reply chain of $id (${treeMatch.reason})');
			}
		}
		return null;
	}

	@override
	bool get supportsMetaFilter => false;

	@override
	bool operator == (Object other) =>
		identical(this, other);
	
	@override
	int get hashCode => identityHashCode(this);
}