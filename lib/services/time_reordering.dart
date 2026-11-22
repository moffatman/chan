/// Moves an item in time-sorted order by changing as few timestamps as possible,
/// without rearranging the input list.
/// Millisecond precision keeps the ordering intact when persisted by Hive.
void reorderByTime<T>(List<T> items, int oldIndex, int newIndex, {
	required DateTime Function(T) getTime,
	required void Function(T, DateTime) setTime,
	required bool reversed
}) {
	if (oldIndex == newIndex) {
		return;
	}
	final reordered = items.toList();
	reordered.insert(newIndex, reordered.removeAt(oldIndex));
	// Work in ascending visual order, regardless of the actual time direction.
	final direction = reversed ? 1 : -1;
	final times = reordered.map((item) => direction * getTime(item).millisecondsSinceEpoch).toList();
	final before = newIndex > 0 ? times[newIndex - 1] : null;
	final after = newIndex < times.length - 1 ? times[newIndex + 1] : null;
	Map<int, int> changes;
	if (before == null) {
		changes = {newIndex: after! - Duration.millisecondsPerMinute};
	}
	else if (after == null) {
		changes = {newIndex: before + Duration.millisecondsPerMinute};
	}
	else if (after - before > 1) {
		changes = {newIndex: before + (after - before) ~/ 2};
	}
	else {
		// No millisecond fits between the neighbors. Compare the smallest local
		// shifts to either side, and (for equal times) splitting the adjustment.
		Map<int, int> shift(int index, int step, int time) {
			final result = <int, int>{};
			while (index >= 0 && index < times.length && (step > 0 ? times[index] < time : times[index] > time)) {
				result[index] = time;
				index += step;
				time += step;
			}
			return result;
		}
		final candidates = [
			shift(newIndex - 1, -1, after - 2),
			shift(newIndex + 1, 1, before + 2),
			if (before == after) {
				...shift(newIndex - 1, -1, before - 1),
				...shift(newIndex + 1, 1, after + 1)
			}
		];
		for (final candidate in candidates) {
			final lower = candidate[newIndex - 1] ?? before;
			final upper = candidate[newIndex + 1] ?? after;
			final time = lower + (upper - lower) ~/ 2;
			if (time != times[newIndex]) {
				candidate[newIndex] = time;
			}
		}
		changes = candidates.reduce((a, b) => a.length <= b.length ? a : b);
	}
	for (final entry in changes.entries) {
		final item = reordered[entry.key];
		final oldTime = getTime(item);
		final newTime = DateTime.fromMillisecondsSinceEpoch(direction * entry.value, isUtc: oldTime.isUtc);
		if (oldTime != newTime) {
			setTime(item, newTime);
		}
	}
}
