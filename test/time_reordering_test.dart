import 'package:chan/services/time_reordering.dart';
import 'package:test/test.dart';

class _Item {
	final int id;
	DateTime time;
	_Item(this.id, this.time);
}

void main() {
	for (final reversed in [false, true]) {
		group('reversed=$reversed', () {
			void check(List<int> times, int from, int to, Set<int> changedIds) {
				final direction = reversed ? 1 : -1;
				final items = [for (int i = 0; i < times.length; i++) _Item(i, DateTime.fromMillisecondsSinceEpoch(direction * times[i], isUtc: true))];
				final originalTimes = items.map((item) => item.time).toList();
				final expected = items.toList();
				expected.insert(to, expected.removeAt(from));
				final writes = <int>[];
				reorderByTime(
					items, from, to,
					reversed: reversed,
					getTime: (item) => item.time,
					setTime: (item, time) {
						item.time = time;
						writes.add(item.id);
					}
				);
				expect(writes.toSet(), changedIds);
				expect(writes.length, changedIds.length, reason: 'Each changed item is persisted once');
				for (final item in items) {
					if (!changedIds.contains(item.id)) {
						expect(item.time, originalTimes[item.id]);
					}
					expect(item.time.isUtc, isTrue);
				}
				final actual = items.toList()..sort((a, b) {
					final result = direction * a.time.compareTo(b.time);
					return result == 0 ? a.id.compareTo(b.id) : result;
				});
				expect(actual, expected);
			}

			test('middle moves preserve all other timestamps', () {
				check([0, 100, 200, 300, 400], 4, 2, {4});
				check([0, 100, 200, 300, 400], 0, 3, {0});
			});
			test('adjacent moves change only the dragged item', () {
				check([0, 100, 200, 300], 1, 2, {1});
				check([0, 100, 200, 300], 2, 1, {2});
			});
			test('end moves change only the dragged item', () {
				check([0, 100, 200, 300], 3, 0, {3});
				check([0, 100, 200, 300], 0, 3, {0});
			});
			test('no-op preserves even tied timestamps', () {
				check([100, 100, 100], 1, 1, {});
			});
			test('tight gap shifts only the less crowded side', () {
				check([0, 1, 2, 20, 100], 4, 2, {2, 4});
				check([0, 10, 11, 12, 100], 4, 2, {1, 4});
			});
			test('ties elsewhere remain untouched', () {
				check([0, 0, 10, 10, 10, 20, 100, 100], 5, 3, {2, 5});
			});
			test('splits a local adjustment when that preserves more timestamps', () {
				check([6, 7, 8, 10, 10, 12, 13, 14, 100], 8, 4, {3, 4, 8});
			});
			test('uses hidden saved threads as neighbors at the visible limit', () {
				check(List.generate(105, (i) => i * 100), 0, 99, {0});
			});
		});
	}
}
